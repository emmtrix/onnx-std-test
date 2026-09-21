#!/usr/bin/env ruby
# frozen_string_literal: true

# Check the binary encoding of Clause 12 of Part 1 against a reference
# implementation.
#
#   scripts/check-encoding.rb
#
# Clause 12 specifies the octets of an ONNX model directly, so that the format
# can be implemented from this standard alone. That is only worth anything if
# what the clause says is what implementations actually write, and the clause
# was written from a reading of the format rather than from a specification
# this standard is allowed to cite. So the rules are restated here as code and
# cross-checked, byte for byte, against the Protocol Buffers runtime.
#
# The encoder below is deliberately naive and self-contained: it is the clause,
# transcribed. If it and the reference disagree, one of the two is wrong and
# the clause is not to be trusted until that is settled.
#
# Coverage: every scalar type the schema of Annex B uses, both field key
# lengths, both repeated forms, and a nested message. The nested case is the
# bootstrap at the end -- a message descriptor is built by encoding a
# FileDescriptorProto with this encoder and handing it to the reference
# library, which will reject it or produce the wrong fields if the encoding is
# wrong. That also supplies the tags above 15 and the packed repeated field
# that the reference library's own bundled types do not have.

require "google/protobuf"
require "google/protobuf/wrappers_pb"
require "google/protobuf/timestamp_pb"

module Wire
  VARINT = 0
  BIT64  = 1
  DELIM  = 2
  BIT32  = 5

  module_function

  # Clause 12.2.2: base-128, least significant group first, high bit set on
  # every octet but the last.
  def varint(value)
    value.negative? and raise ArgumentError, "varint of a negative value"

    out = +""
    loop do
      group = value & 0x7F
      value >>= 7
      return (out << group.chr).b if value.zero?

      out << (group | 0x80).chr
    end
  end

  # Clause 12.2.3: a signed integer is the varint of its 64-bit two's
  # complement, so every negative value occupies ten octets.
  def signed(value) = varint(value.negative? ? value + (1 << 64) : value)

  # Clause 12.3.1: the key is the varint of (tag << 3) | wire type.
  def key(tag, wire_type) = varint((tag << 3) | wire_type)

  # Clause 12.2.5.
  def delimited(octets) = varint(octets.bytesize) + octets.b

  # Clause 12.2.4.
  def bit32(value) = [value].pack("e")
  def bit64(value) = [value].pack("E")

  def read_varint(octets, at)
    value = 0
    shift = 0
    loop do
      byte = octets.getbyte(at) or raise "truncated varint"
      at += 1
      value |= (byte & 0x7F) << shift
      return [value, at] if (byte & 0x80).zero?

      shift += 7
      shift >= 70 and raise "varint longer than ten octets"
    end
  end

  # Clause 12.4: read a message as a sequence of fields without knowing any of
  # them, which is what skipping an unknown field requires.
  def scan(octets)
    octets = octets.b
    at = 0
    fields = []
    while at < octets.bytesize
      k, at = read_varint(octets, at)
      tag = k >> 3
      wire_type = k & 7
      case wire_type
      when VARINT
        value, at = read_varint(octets, at)
        fields << [tag, wire_type, value]
      when BIT64
        fields << [tag, wire_type, octets.byteslice(at, 8)]
        at += 8
      when BIT32
        fields << [tag, wire_type, octets.byteslice(at, 4)]
        at += 4
      when DELIM
        length, at = read_varint(octets, at)
        fields << [tag, wire_type, octets.byteslice(at, length)]
        at += length
      else
        raise "wire type #{wire_type} is not admitted"
      end
    end
    fields
  end
end

# ---------------------------------------------------------------- comparison

FAILURES = []

def compare(name, mine, reference)
  if mine.b == reference.b
    puts format("  ok    %-34s %s", name, mine.unpack1("H*"))
  else
    FAILURES << name
    puts format("  FAIL  %-34s %s", name, mine.unpack1("H*"))
    puts format("        %-34s %s  (reference)", "", reference.unpack1("H*"))
  end
end

W = Google::Protobuf

puts "Clause 12 against google-protobuf " \
     "#{Gem.loaded_specs['google-protobuf']&.version}"
puts
puts "Scalar types and field keys"

[
  ["int32 zero (absent)",   W::Int32Value.new(value: 0),  -> { "" }],
  ["int32 one",             W::Int32Value.new(value: 1),
   -> { Wire.key(1, Wire::VARINT) + Wire.signed(1) }],
  ["int32 300 (two groups)", W::Int32Value.new(value: 300),
   -> { Wire.key(1, Wire::VARINT) + Wire.signed(300) }],
  ["int32 minus one",       W::Int32Value.new(value: -1),
   -> { Wire.key(1, Wire::VARINT) + Wire.signed(-1) }],
  ["int64 minus two",       W::Int64Value.new(value: -2),
   -> { Wire.key(1, Wire::VARINT) + Wire.signed(-2) }],
  ["int64 largest",         W::Int64Value.new(value: (1 << 63) - 1),
   -> { Wire.key(1, Wire::VARINT) + Wire.signed((1 << 63) - 1) }],
  ["uint64 largest",        W::UInt64Value.new(value: (1 << 64) - 1),
   -> { Wire.key(1, Wire::VARINT) + Wire.varint((1 << 64) - 1) }],
  ["bool true",             W::BoolValue.new(value: true),
   -> { Wire.key(1, Wire::VARINT) + Wire.varint(1) }],
  ["float 1.5",             W::FloatValue.new(value: 1.5),
   -> { Wire.key(1, Wire::BIT32) + Wire.bit32(1.5) }],
  ["float negative zero",   W::FloatValue.new(value: -0.0),
   -> { Wire.key(1, Wire::BIT32) + Wire.bit32(-0.0) }],
  ["double 1.5",            W::DoubleValue.new(value: 1.5),
   -> { Wire.key(1, Wire::BIT64) + Wire.bit64(1.5) }],
  ["string ASCII",          W::StringValue.new(value: "abc"),
   -> { Wire.key(1, Wire::DELIM) + Wire.delimited("abc") }],
  ["string beyond ASCII",   W::StringValue.new(value: "aä€"),
   -> { Wire.key(1, Wire::DELIM) + Wire.delimited("aä€") }],
  ["bytes with NUL and FF", W::BytesValue.new(value: "\x00\xFF".b),
   -> { Wire.key(1, Wire::DELIM) + Wire.delimited("\x00\xFF".b) }],
  ["two fields in order",   W::Timestamp.new(seconds: -1, nanos: 7),
   -> {
     Wire.key(1, Wire::VARINT) + Wire.signed(-1) +
       Wire.key(2, Wire::VARINT) + Wire.signed(7)
   }],
].each { |name, message, mine| compare(name, mine.call, message.to_proto) }

# ------------------------------------------------------- descriptor bootstrap

# descriptor.proto, only the fields needed here.
FIELD_NAME = 1
FIELD_NUMBER = 3
FIELD_LABEL = 4
FIELD_TYPE = 5
FIELD_OPTIONS = 8
FIELD_JSON_NAME = 10
OPTION_PACKED = 2
LABEL_OPTIONAL = 1
LABEL_REPEATED = 3
TYPE_INT64 = 3
TYPE_INT32 = 5
TYPE_STRING = 9

def field_descriptor(name, number, type, label: LABEL_OPTIONAL, packed: nil)
  out = Wire.key(FIELD_NAME, Wire::DELIM) + Wire.delimited(name)
  out += Wire.key(FIELD_NUMBER, Wire::VARINT) + Wire.signed(number)
  out += Wire.key(FIELD_LABEL, Wire::VARINT) + Wire.varint(label)
  out += Wire.key(FIELD_TYPE, Wire::VARINT) + Wire.varint(type)
  out += Wire.key(FIELD_JSON_NAME, Wire::DELIM) + Wire.delimited(name)
  unless packed.nil?
    options = Wire.key(OPTION_PACKED, Wire::VARINT) + Wire.varint(packed ? 1 : 0)
    out += Wire.key(FIELD_OPTIONS, Wire::DELIM) + Wire.delimited(options)
  end
  out
end

FIELDS = [
  ["low",      1, TYPE_INT32,  LABEL_OPTIONAL, nil],
  ["high",    20, TYPE_INT32,  LABEL_OPTIONAL, nil],
  ["higher",  26, TYPE_STRING, LABEL_OPTIONAL, nil],
  ["packed",   5, TYPE_INT64,  LABEL_REPEATED, true],
  ["plain",    6, TYPE_INT64,  LABEL_REPEATED, false],
].freeze

message = Wire.key(1, Wire::DELIM) + Wire.delimited("Probe")
FIELDS.each do |name, number, type, label, packed|
  message += Wire.key(2, Wire::DELIM) +
             Wire.delimited(field_descriptor(name, number, type,
                                             label: label, packed: packed))
end

file = Wire.key(1, Wire::DELIM) + Wire.delimited("probe.proto")
file += Wire.key(2, Wire::DELIM) + Wire.delimited("probe")
file += Wire.key(4, Wire::DELIM) + Wire.delimited(message)
file += Wire.key(12, Wire::DELIM) + Wire.delimited("proto2")

pool = Google::Protobuf::DescriptorPool.new
begin
  pool.add_serialized_file(file)
rescue StandardError => e
  warn "\nthe reference library rejected a descriptor this encoder produced:"
  warn "  #{e.message}"
  exit 1
end

descriptor = pool.lookup("probe.Probe")
puts
puts "Nested messages, by building a descriptor with this encoder"
FIELDS.each do |name, number, _type, label, _packed|
  field = descriptor.lookup(name)
  wanted = [number, label == LABEL_REPEATED ? :repeated : :optional]
  got = [field.number, field.label]
  if got == wanted
    puts format("  ok    %-34s tag %d, %s", name, field.number, field.label)
  else
    FAILURES << "descriptor #{name}"
    puts format("  FAIL  %-34s got %p, wanted %p", name, got, wanted)
  end
end

probe = descriptor.msgclass
puts
puts "Field keys above tag 15, and repeated fields"
[
  ["tag 1, one-octet key",   probe.new(low: 7),
   -> { Wire.key(1, Wire::VARINT) + Wire.signed(7) }],
  ["tag 20, two-octet key",  probe.new(high: 7),
   -> { Wire.key(20, Wire::VARINT) + Wire.signed(7) }],
  ["tag 26, length-delimited", probe.new(higher: "x"),
   -> { Wire.key(26, Wire::DELIM) + Wire.delimited("x") }],
  ["repeated, packed",       probe.new(packed: [1, 300, -1]),
   -> {
     Wire.key(5, Wire::DELIM) +
       Wire.delimited(Wire.signed(1) + Wire.signed(300) + Wire.signed(-1))
   }],
  ["repeated, not packed",   probe.new(plain: [1, 300]),
   -> {
     Wire.key(6, Wire::VARINT) + Wire.signed(1) +
       Wire.key(6, Wire::VARINT) + Wire.signed(300)
   }],
].each { |name, message_value, mine| compare(name, mine.call, message_value.to_proto) }

# ------------------------------------------------------- examples and mixing

# The worked examples of Clause 12 give literal octets. They are checked here
# so that an edit to the clause that makes one of them wrong fails the build.
puts
puts "The worked examples of the clause"
[
  ["12.2.2  1",            Wire.varint(1),                      "01"],
  ["12.2.2  300",          Wire.varint(300),                    "ac02"],
  ["12.2.3  -1",           Wire.signed(-1),                     "ffffffffffffffffff01"],
  ["12.3.1  tag 1, type 0", Wire.key(1, Wire::VARINT),          "08"],
  ["12.3.1  tag 20, type 0", Wire.key(20, Wire::VARINT),        "a001"],
  ["12.3.3  packed",
   Wire.key(5, Wire::DELIM) + Wire.delimited(Wire.signed(1) + Wire.signed(300)),
   "2a0301ac02"],
  ["12.3.3  unpacked",
   Wire.key(5, Wire::VARINT) + Wire.signed(1) +
     Wire.key(5, Wire::VARINT) + Wire.signed(300),
   "2801 28ac02".delete(" ")],
].each do |name, mine, wanted|
  compare(name, mine, [wanted].pack("H*"))
end

# Clause 12.3.3 requires a consumer to accept both forms of one repeated field
# in one message, concatenating in order of appearance. Checked against the
# reference rather than asserted.
puts
puts "Both forms of one repeated field in one message"
mixed = Wire.key(5, Wire::DELIM) + Wire.delimited(Wire.signed(1) + Wire.signed(2)) +
        Wire.key(5, Wire::VARINT) + Wire.signed(3)
got = probe.decode(mixed).packed.to_a
if got == [1, 2, 3]
  puts format("  ok    %-34s %p", "packed then unpacked", got)
else
  FAILURES << "mixed repeated forms"
  puts format("  FAIL  %-34s got %p, wanted [1, 2, 3]", "packed then unpacked", got)
end

# ------------------------------------------------------------------- scanning

puts
puts "Reading a message without knowing its fields"
sample = probe.new(low: 1, high: 2, higher: "x", packed: [7], plain: [8]).to_proto
seen = Wire.scan(sample).map { |tag, wire_type, _| [tag, wire_type] }
wanted = [[1, Wire::VARINT], [5, Wire::DELIM], [6, Wire::VARINT],
          [20, Wire::VARINT], [26, Wire::DELIM]]
if seen.sort == wanted.sort
  puts format("  ok    %-34s %p", "every field located", seen)
else
  FAILURES << "scan"
  puts format("  FAIL  %-34s got %p, wanted %p", "scan", seen, wanted)
end

puts
if FAILURES.empty?
  puts "encoding: the clause and the reference implementation agree"
else
  warn "encoding: #{FAILURES.length} disagreement(s): #{FAILURES.join(', ')}"
  warn "          Clause 12 of Part 1 is wrong, or this transcription of it is."
  exit 1
end

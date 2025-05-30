package xkb

import "base:runtime"
import "core:log"
import "core:os"
import "core:reflect"
import "core:testing"
import "core:unicode"

import "lib:collection/vector"
import "lib:error"

@(private)
Identifier :: distinct []u8
@(private)
Name :: distinct []u8
@(private)
String :: distinct []u8

@(private)
Keyword :: enum {
  Keymap,
  Keycodes,
  Types,
  Compatibility,
  Symbols,
}

@(private)
Symbol :: enum {
  Greater,
  Less,
  SquareOpen,
  SquareClose,
  Semicolon,
  BraceOpen,
  BraceClose,
  ParenOpen,
  ParenClose,
  Plus,
  Minus,
  Comma,
  Equal,
  Dot,
  Bang,
  Eof,
}

@(private)
Token :: union {
  Symbol,
  Identifier,
  String,
  Keyword,
  Name,
}

@(private)
Xkb_Keycodes :: struct {
  name:    String,
  minimum: u32,
  maximum: u32,
  pairs:   map[u32]u32,
}

@(private)
Xkb_Type_Map :: struct {
  modifiers: []Modifier,
  number:    u32,
}

@(private)
Xkb_Type_Preserve :: struct {
  modifiers: []Modifier,
  value:     Modifier,
}

@(private)
Xkb_Type_Level :: struct {
  number: u32,
  value:  String,
}

@(private)
Xkb_Type :: struct {
  name:      String,
  modifiers: []Modifier,
  maps:      []Xkb_Type_Map,
  levels:    []Xkb_Type_Level,
  preserves: []Xkb_Type_Preserve,
}

@(private)
Xkb_Types :: struct {
  name:      String,
  modifiers: []Modifier,
  types:     []Xkb_Type,
}

@(private)
Xkb_Compatibility_Interpret_Match_Kind :: enum {
  AnyOf,
  Exactly,
  AnyOfOrNone,
}

@(private)
Xkb_Compatibility_Interpret_Match :: struct {
  key:       Code,
  kind:      Xkb_Compatibility_Interpret_Match_Kind,
  modifiers: []Modifier,
}

@(private)
Xkb_Compatibility_Action_Attribute :: Identifier

@(private)
Xkb_Compatibility_Action_MovePtr :: struct {
  x: i32,
  y: i32,
}

@(private)
Xkb_Compatibility_Action_Mods :: struct {
  modifiers:  Modifier,
  attributes: []Xkb_Compatibility_Action_Attribute,
}

@(private)
Xkb_Compatibility_Action_LockMods :: distinct Xkb_Compatibility_Action_Mods
@(private)
Xkb_Compatibility_Action_LatchMods :: distinct Xkb_Compatibility_Action_Mods
@(private)
Xkb_Compatibility_Action_SetMods :: distinct Xkb_Compatibility_Action_Mods

@(private)
Xkb_Compatibility_Action_Controls :: struct {
  value: Identifier,
}

@(private)
Xkb_Compatibility_Action_LockControls :: distinct
Xkb_Compatibility_Action_Controls
@(private)
Xkb_Compatibility_Action_LatchControls :: distinct
Xkb_Compatibility_Action_Controls
@(private)
Xkb_Compatibility_Action_SetControls :: distinct
Xkb_Compatibility_Action_Controls

@(private)
Xkb_Compatibility_Action_Group :: struct {
  value: i32,
}

@(private)
Xkb_Compatibility_Action_LockGroup :: distinct Xkb_Compatibility_Action_Group
@(private)
Xkb_Compatibility_Action_SetGroup :: distinct Xkb_Compatibility_Action_Group
@(private)
Xkb_Compatibility_Action_LatchGroup :: distinct Xkb_Compatibility_Action_Group
@(private)
Xkb_Compatibility_Action_Terminate :: struct {
}

@(private)
Xkb_Compatibility_Action_Switch :: struct {
  screen:     u32,
  attributes: Identifier,
}

@(private)
Xkb_Compatibility_Action_Private :: struct {
  kind:       Identifier,
  attributes: Identifier,
  data:       []Identifier,
}

@(private)
Xkb_Compatibility_Action_Ptr :: struct {
  affect: Identifier,
  button: i32,
  count:  u32,
}

@(private)
Xkb_Compatibility_Action_SetPtr :: distinct Xkb_Compatibility_Action_Ptr
@(private)
Xkb_Compatibility_Action_LockPtrBtn :: distinct Xkb_Compatibility_Action_Ptr
@(private)
Xkb_Compatibility_Action_PtrBtn :: distinct Xkb_Compatibility_Action_Ptr

@(private)
Xkb_Compatibility_Action_SwitchScreen :: struct {
  value: u32,
  same:  bool,
}

@(private)
Xkb_Compatibility_Interpret_Action :: union {
  Xkb_Compatibility_Action_MovePtr,
  Xkb_Compatibility_Action_LockMods,
  Xkb_Compatibility_Action_LatchMods,
  Xkb_Compatibility_Action_SetMods,
  Xkb_Compatibility_Action_LockGroup,
  Xkb_Compatibility_Action_SetGroup,
  Xkb_Compatibility_Action_LatchGroup,
  Xkb_Compatibility_Action_LockControls,
  Xkb_Compatibility_Action_LatchControls,
  Xkb_Compatibility_Action_SetControls,
  Xkb_Compatibility_Action_Terminate,
  Xkb_Compatibility_Action_Private,
  Xkb_Compatibility_Action_SetPtr,
  Xkb_Compatibility_Action_LockPtrBtn,
  Xkb_Compatibility_Action_PtrBtn,
  Xkb_Compatibility_Action_SwitchScreen,
}

@(private)
Xkb_Compatibility_Interpret :: struct {
  match:    Xkb_Compatibility_Interpret_Match,
  action:   Xkb_Compatibility_Interpret_Action,
  modifier: Modifier,
  mods:     Identifier,
  repeat:   bool,
}

@(private)
Xkb_Compatibility_Indicator :: struct {
  name:     String,
  modifier: Modifier,
  state:    Identifier,
  groups:   Identifier,
  controls: Identifier,
}

@(private)
Xkb_Compatibility :: struct {
  name:           String,
  modifiers:      []Modifier,
  interprets:     []Xkb_Compatibility_Interpret,
  indicators:     []Xkb_Compatibility_Indicator,
  default_mods:   Identifier,
  default_repeat: bool,
  default_action: Xkb_Compatibility_Interpret_Action,
}

@(private)
Xkb_Symbols_Pair :: struct {
  key:   u32,
  codes: []Code,
}

@(private)
Xkb_Symbols_Map :: struct {
  modifier: Modifier,
  codes:    []u32,
}

@(private)
Xkb_Symbols :: struct {
  name:  String,
  pairs: []Xkb_Symbols_Pair,
  maps:  []Xkb_Symbols_Map,
}

@(private)
Tokenizer :: struct {
  line:            u32,
  offset:          u32,
  token:           Token,
  bytes:           []u8,
  keycodes:        Xkb_Keycodes,
  types:           Xkb_Types,
  compatibility:   Xkb_Compatibility,
  symbols:         Xkb_Symbols,
  xkb_types:       vector.Vector(Xkb_Type),
  xkb_maps:        vector.Vector(Xkb_Type_Map),
  xkb_levels:      vector.Vector(Xkb_Type_Level),
  xkb_preserves:   vector.Vector(Xkb_Type_Preserve),
  xkb_interprets:  vector.Vector(Xkb_Compatibility_Interpret),
  xkb_indicators:  vector.Vector(Xkb_Compatibility_Indicator),
  pairs:           vector.Vector(Xkb_Symbols_Pair),
  maps:            vector.Vector(Xkb_Symbols_Map),
  codes:           vector.Vector(Code),
  identifiers:     vector.Vector(Identifier),
  modifiers:       vector.Vector(Modifier),
  numbers:         vector.Vector(u32),
  code_equivalent: map[string]Code,
}

@(private)
KeyCode :: struct {
  key:    u32,
  values: []Code,
}

@(private)
Modifier :: enum {
  Shift = 0,
  Control = 2,
  Alt = 3,
  Super = 6,
  NumLock,
  LevelThree,
  LevelFive,
  Meta,
  Hyper,
  ScrollLock,
  Lock,
}

@(private)
Modifiers :: bit_set[Modifier;u32]

Keymap_Context :: struct {
  codes:         map[u32][]Code,
  modifiers:     Modifiers,
  pressed_map:   #sparse[Code]bool,
  pressed_array: vector.Vector(Code),
}

keymap_from_bytes :: proc(
  bytes: []u8,
  allocator: runtime.Allocator,
  tmp_allocator: runtime.Allocator,
) -> (
  keymap: Keymap_Context,
  err: error.Error,
) {
  log.info("Parsing Keymap")

  tokenizer := parse_keymap(bytes, tmp_allocator) or_return

  keymap.codes = make(map[u32][]Code, 100, allocator)
  keymap.pressed_array = vector.new(Code, 20, allocator) or_return

  for i in 0 ..< tokenizer.pairs.len {
    pair := &tokenizer.pairs.data[i]

    if len(pair.codes) != 0 {
      id := tokenizer.keycodes.pairs[pair.key]
      keymap.codes[id] = pair.codes
    }
  }

  return keymap, nil
}

register_code :: proc(
  keymap: ^Keymap_Context,
  id: u32,
  state: u32,
) -> error.Error {
  value, ok := keymap.codes[id + 8]

  if ok && len(value) > 0 {
    index := 0

    if .Shift in keymap.modifiers {
      index = 1
    }

    code := value[index % len(value)]

    if state == 1 {
      keymap.pressed_map[code] = true
      vector.append(&keymap.pressed_array, code) or_return
    } else if state == 0 {
      for i in 0 ..< keymap.pressed_array.len {
        if keymap.pressed_array.data[i] == code {
          vector.remove(&keymap.pressed_array, i)
          break
        }
      }

      keymap.pressed_map[code] = false
    }
  }

  return nil
}

is_key_pressed :: proc(keymap: ^Keymap_Context, code: Code) -> bool {
  return keymap.pressed_map[code]
}

set_modifiers :: proc(keymap: ^Keymap_Context, mask: u32) {
  keymap.modifiers = transmute(Modifiers)(mask)
}

@(private)
parse_keymap :: proc(
  bytes: []u8,
  allocator: runtime.Allocator,
) -> (
  tokenizer: Tokenizer,
  err: error.Error,
) {
  tokenizer = Tokenizer {
    bytes  = bytes,
    offset = 0,
    line   = 0,
  }

  tokenizer.xkb_types = vector.new(Xkb_Type, 50, allocator) or_return
  tokenizer.xkb_maps = vector.new(Xkb_Type_Map, 200, allocator) or_return
  tokenizer.xkb_levels = vector.new(Xkb_Type_Level, 150, allocator) or_return
  tokenizer.xkb_preserves = vector.new(
    Xkb_Type_Preserve,
    30,
    allocator,
  ) or_return
  tokenizer.xkb_interprets = vector.new(
    Xkb_Compatibility_Interpret,
    200,
    allocator,
  ) or_return
  tokenizer.xkb_indicators = vector.new(
    Xkb_Compatibility_Indicator,
    10,
    allocator,
  ) or_return
  tokenizer.codes = vector.new(Code, 200, allocator) or_return
  tokenizer.pairs = vector.new(Xkb_Symbols_Pair, 100, allocator) or_return
  tokenizer.maps = vector.new(Xkb_Symbols_Map, 10, allocator) or_return
  tokenizer.identifiers = vector.new(Identifier, 100, allocator) or_return
  tokenizer.modifiers = vector.new(Modifier, 500, allocator) or_return
  tokenizer.numbers = vector.new(u32, 50, allocator) or_return

  tokenizer.keycodes.pairs = make(map[u32]u32, 1000, allocator)
  tokenizer.code_equivalent = make(map[string]Code, 500, allocator)

  tokenizer.code_equivalent["Escape"] = .Escape
  tokenizer.code_equivalent["exclam"] = .Exclamation
  tokenizer.code_equivalent["space"] = .Space
  tokenizer.code_equivalent["quotedbl"] = .DoubleQuote
  tokenizer.code_equivalent["numbersign"] = .NumberSign
  tokenizer.code_equivalent["dolarsign"] = .DolarSign
  tokenizer.code_equivalent["percent"] = .Percent
  tokenizer.code_equivalent["asciicircum"] = .AsciiCircum
  tokenizer.code_equivalent["asterisk"] = .Asterisk
  tokenizer.code_equivalent["parenleft"] = .ParenLeft
  tokenizer.code_equivalent["parenright"] = .ParenRight
  tokenizer.code_equivalent["minus"] = .Minus
  tokenizer.code_equivalent["underscore"] = .Underscore
  tokenizer.code_equivalent["equal"] = .Equal
  tokenizer.code_equivalent["Return"] = .Return
  tokenizer.code_equivalent["Up"] = .ArrowUp
  tokenizer.code_equivalent["Down"] = .ArrowDown
  tokenizer.code_equivalent["Left"] = .ArrowLeft
  tokenizer.code_equivalent["Right"] = .ArrowRight

  tokenizer.code_equivalent["1"] = .One
  tokenizer.code_equivalent["2"] = .Two
  tokenizer.code_equivalent["3"] = .Three
  tokenizer.code_equivalent["4"] = .Four
  tokenizer.code_equivalent["5"] = .Five
  tokenizer.code_equivalent["6"] = .Six
  tokenizer.code_equivalent["7"] = .Seven
  tokenizer.code_equivalent["8"] = .Eight
  tokenizer.code_equivalent["9"] = .Nine
  tokenizer.code_equivalent["0"] = .Zero

  tokenizer.code_equivalent["semicolon"] = .Semicolon
  tokenizer.code_equivalent["colon"] = .Colon
  tokenizer.code_equivalent["apostrophe"] = .AsciiCircum
  tokenizer.code_equivalent["plus"] = .Plus
  tokenizer.code_equivalent["comma"] = .Comma
  tokenizer.code_equivalent["period"] = .Dot
  tokenizer.code_equivalent["slash"] = .Bar
  tokenizer.code_equivalent["question"] = .QuestioMark
  tokenizer.code_equivalent["backslash"] = .CounterBar
  tokenizer.code_equivalent["bar"] = .Pipe
  tokenizer.code_equivalent["less"] = .Less
  tokenizer.code_equivalent["greater"] = .Greater

  tokenizer.code_equivalent["q"] = .q
  tokenizer.code_equivalent["Q"] = .Q
  tokenizer.code_equivalent["w"] = .w
  tokenizer.code_equivalent["W"] = .W
  tokenizer.code_equivalent["e"] = .e
  tokenizer.code_equivalent["E"] = .E
  tokenizer.code_equivalent["r"] = .r
  tokenizer.code_equivalent["R"] = .R
  tokenizer.code_equivalent["t"] = .t
  tokenizer.code_equivalent["T"] = .T
  tokenizer.code_equivalent["y"] = .y
  tokenizer.code_equivalent["Y"] = .Y
  tokenizer.code_equivalent["u"] = .u
  tokenizer.code_equivalent["U"] = .U
  tokenizer.code_equivalent["i"] = .i
  tokenizer.code_equivalent["I"] = .I
  tokenizer.code_equivalent["o"] = .o
  tokenizer.code_equivalent["O"] = .O
  tokenizer.code_equivalent["p"] = .p
  tokenizer.code_equivalent["P"] = .P
  tokenizer.code_equivalent["a"] = .a
  tokenizer.code_equivalent["A"] = .A
  tokenizer.code_equivalent["s"] = .s
  tokenizer.code_equivalent["S"] = .S
  tokenizer.code_equivalent["d"] = .d
  tokenizer.code_equivalent["D"] = .D
  tokenizer.code_equivalent["f"] = .f
  tokenizer.code_equivalent["F"] = .F
  tokenizer.code_equivalent["g"] = .g
  tokenizer.code_equivalent["G"] = .G
  tokenizer.code_equivalent["h"] = .h
  tokenizer.code_equivalent["H"] = .H
  tokenizer.code_equivalent["j"] = .j
  tokenizer.code_equivalent["J"] = .J
  tokenizer.code_equivalent["k"] = .k
  tokenizer.code_equivalent["K"] = .K
  tokenizer.code_equivalent["l"] = .l
  tokenizer.code_equivalent["L"] = .L
  tokenizer.code_equivalent["z"] = .z
  tokenizer.code_equivalent["Z"] = .Z
  tokenizer.code_equivalent["x"] = .x
  tokenizer.code_equivalent["X"] = .X
  tokenizer.code_equivalent["c"] = .c
  tokenizer.code_equivalent["C"] = .C
  tokenizer.code_equivalent["v"] = .v
  tokenizer.code_equivalent["V"] = .V
  tokenizer.code_equivalent["b"] = .b
  tokenizer.code_equivalent["B"] = .B
  tokenizer.code_equivalent["n"] = .n
  tokenizer.code_equivalent["N"] = .N
  tokenizer.code_equivalent["m"] = .m
  tokenizer.code_equivalent["M"] = .M

  advance(&tokenizer) or_return
  assert_type(&tokenizer, Keyword) or_return
  assert_keyword(&tokenizer, .Keymap) or_return

  advance(&tokenizer) or_return
  assert_type(&tokenizer, Symbol) or_return
  assert_symbol(&tokenizer, .BraceOpen) or_return

  for advance(&tokenizer) == nil {
    assert_type(&tokenizer, Keyword) or_break

    #partial switch tokenizer.token.(Keyword) {
    case .Keycodes:
      parse_keycodes(&tokenizer, allocator) or_return
    case .Types:
      parse_types(&tokenizer, allocator) or_return
    case .Compatibility:
      parse_compatibility(&tokenizer, allocator) or_return
    case .Symbols:
      parse_symbols(&tokenizer, allocator) or_return
    case:
      return tokenizer, .KeywordAssertionFailed
    }
  }

  return tokenizer, nil
}

@(private)
key_pair_from_bytes :: proc(identifier: []u8) -> u32 {
  key: u32 = 0
  for i in 0 ..< len(identifier) {
    key = u32(key << 8) + u32(identifier[i])
  }

  return key
}

@(private)
parse_keycodes_indicator :: proc(tokenizer: ^Tokenizer) -> error.Error {
  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, String) or_return

  return nil
}

@(private)
parse_keycodes_alias :: proc(tokenizer: ^Tokenizer) -> error.Error {
  advance(tokenizer) or_return
  assert_type(tokenizer, Name) or_return
  key := key_pair_from_bytes(([]u8)(tokenizer.token.(Name)))

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal)

  advance(tokenizer) or_return
  assert_type(tokenizer, Name) or_return

  value := key_pair_from_bytes(([]u8)(tokenizer.token.(Name)))

  tokenizer.keycodes.pairs[key] = tokenizer.keycodes.pairs[value]

  return nil
}

@(private)
parse_keycodes_property :: proc(tokenizer: ^Tokenizer) -> error.Error {
  out: ^u32
  if assert_identifier(tokenizer, Identifier(minimum_word[:])) == nil {
    out = &tokenizer.keycodes.minimum
  } else if assert_identifier(tokenizer, Identifier(maximum_word[:])) == nil {
    out = &tokenizer.keycodes.maximum
  }

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return

  out^ = to_number(tokenizer.token.(Identifier)) or_return

  return nil
}


@(private)
parse_keycodes_pair :: proc(tokenizer: ^Tokenizer) -> error.Error {
  key := key_pair_from_bytes(([]u8)(tokenizer.token.(Name)))

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return

  tokenizer.keycodes.pairs[key] = to_number(
    tokenizer.token.(Identifier),
  ) or_return

  return nil
}

@(private)
parse_keycodes :: proc(
  tokenizer: ^Tokenizer,
  allocator: runtime.Allocator,
) -> error.Error {
  advance(tokenizer) or_return
  assert_type(tokenizer, String) or_return
  tokenizer.keycodes.name = tokenizer.token.(String)

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceOpen) or_return

  advance(tokenizer) or_return
  for assert_type(tokenizer, Symbol) != nil {
    #partial switch t in tokenizer.token {
    case Identifier:
      if assert_identifier(tokenizer, Identifier(indicator[:])) == nil {
        parse_keycodes_indicator(tokenizer) or_return
      } else if assert_identifier(tokenizer, Identifier(alias[:])) == nil {
        parse_keycodes_alias(tokenizer) or_return
      } else {
        parse_keycodes_property(tokenizer) or_return
      }
    case Name:
      parse_keycodes_pair(tokenizer)
    case:
      panic("SHOULD NOT BE HERE")
    }

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Semicolon) or_return

    advance(tokenizer) or_return
  }

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Semicolon) or_return

  return nil
}

@(private)
modifier_from_bytes :: proc(bytes: []u8) -> (Modifier, bool) {
  if eql(numlock_word[:], bytes) {
    return .NumLock, true
  } else if eql(alt_word[:], bytes) {
    return .Alt, true
  } else if eql(shift_word[:], bytes) {
    return .Shift, true
  } else if eql(control_word[:], bytes) {
    return .Control, true
  } else if eql(meta_word[:], bytes) {
    return .Meta, true
  } else if eql(hyper_word[:], bytes) {
    return .Hyper, true
  } else if eql(super_word[:], bytes) {
    return .Super, true
  } else if eql(level_three_word[:], bytes) {
    return .LevelThree, true
  } else if eql(level_five_word[:], bytes) {
    return .LevelFive, true
  } else if eql(scroll_lock_word[:], bytes) {
    return .ScrollLock, true
  } else if eql(lock_word[:], bytes) {
    return .Lock, true
  }

  return nil, false
}

@(private)
parse_modifier_combination :: proc(tokenizer: ^Tokenizer) -> error.Error {
  outer: for assert_type(tokenizer, Identifier) == nil {
    modifier, ok := modifier_from_bytes(
      cast([]u8)(tokenizer.token.(Identifier)),
    )

    if !ok {
      advance(tokenizer) or_return
      return nil
    }

    vector.append(&tokenizer.modifiers, modifier) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return

    #partial switch tokenizer.token.(Symbol) {
    case .Plus:
      advance(tokenizer) or_return
    case:
      break outer
    }
  }

  return nil
}

@(private)
parse_map :: proc(tokenizer: ^Tokenizer) -> error.Error {
  xkb_map: Xkb_Type_Map
  advance(tokenizer) or_return

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .SquareOpen) or_return

  advance(tokenizer) or_return

  start := tokenizer.modifiers.len
  parse_modifier_combination(tokenizer) or_return

  xkb_map.modifiers = vector.offset(&tokenizer.modifiers, start) or_return

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .SquareClose) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return
  xkb_map.number = to_number(tokenizer.token.(Identifier)) or_return

  advance(tokenizer) or_return

  vector.append(&tokenizer.xkb_maps, xkb_map) or_return

  return nil
}

@(private)
parse_preserve :: proc(tokenizer: ^Tokenizer) -> error.Error {
  preserve: Xkb_Type_Preserve

  advance(tokenizer) or_return

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .SquareOpen) or_return

  advance(tokenizer) or_return

  start := tokenizer.modifiers.len
  parse_modifier_combination(tokenizer) or_return

  preserve.modifiers = vector.offset(&tokenizer.modifiers, start) or_return

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .SquareClose) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return

  ok: bool
  preserve.value, ok = modifier_from_bytes(
    cast([]u8)(tokenizer.token.(Identifier)),
  )

  if !ok {
    return .TypeAssertionFailed
  }

  advance(tokenizer) or_return

  vector.append(&tokenizer.xkb_preserves, preserve) or_return

  return nil
}

@(private)
parse_level_name :: proc(tokenizer: ^Tokenizer) -> error.Error {
  level: Xkb_Type_Level

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .SquareOpen) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return
  level.number = to_number(tokenizer.token.(Identifier)) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .SquareClose) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, String) or_return
  level.value = tokenizer.token.(String)

  advance(tokenizer) or_return

  vector.append(&tokenizer.xkb_levels, level) or_return

  return nil
}

@(private)
parse_type :: proc(tokenizer: ^Tokenizer) -> error.Error {
  typ: Xkb_Type

  assert_identifier(tokenizer, Identifier(type_word[:])) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, String) or_return

  typ.name = tokenizer.token.(String)

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceOpen) or_return

  map_start := tokenizer.xkb_maps.len
  preserve_start := tokenizer.xkb_preserves.len
  level_start := tokenizer.xkb_levels.len

  advance(tokenizer) or_return
  for assert_type(tokenizer, Identifier) == nil {
    property := cast([]u8)(tokenizer.token.(Identifier))

    if eql(property, map_word[:]) {
      parse_map(tokenizer) or_return
    } else if eql(property, level_name_word[:]) {
      parse_level_name(tokenizer) or_return
    } else if eql(property, modifiers_word[:]) {
      advance(tokenizer) or_return
      assert_type(tokenizer, Symbol) or_return
      assert_symbol(tokenizer, .Equal) or_return

      advance(tokenizer) or_return

      start := tokenizer.modifiers.len
      parse_modifier_combination(tokenizer) or_return
      typ.modifiers = vector.offset(&tokenizer.modifiers, start) or_return
    } else if eql(property, preserve_word[:]) {
      parse_preserve(tokenizer) or_return
    } else {
      return .TypeAssertionFailed
    }

    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Semicolon) or_return
    advance(tokenizer) or_return
  }

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceClose) or_return
  advance(tokenizer) or_return

  typ.levels = vector.offset(&tokenizer.xkb_levels, level_start) or_return
  typ.maps = vector.offset(&tokenizer.xkb_maps, map_start) or_return
  typ.preserves = vector.offset(
    &tokenizer.xkb_preserves,
    preserve_start,
  ) or_return

  vector.append(&tokenizer.xkb_types, typ) or_return

  return nil
}

@(private)
parse_types :: proc(
  tokenizer: ^Tokenizer,
  allocator: runtime.Allocator,
) -> error.Error {
  advance(tokenizer) or_return
  assert_type(tokenizer, String) or_return
  tokenizer.types.name = tokenizer.token.(String)

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceOpen) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return
  assert_identifier(tokenizer, Identifier(virtual_modifiers_word[:]))

  start := tokenizer.modifiers.len
  advance(tokenizer) or_return
  for assert_type(tokenizer, Identifier) == nil {
    modifier, ok := modifier_from_bytes(
      cast([]u8)(tokenizer.token.(Identifier)),
    )

    if !ok {
      return .ModifierNotFound
    }

    vector.append(&tokenizer.modifiers, modifier) or_return
    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return

    if assert_symbol(tokenizer, .Comma) != nil do break
    advance(tokenizer) or_return
  }

  tokenizer.types.modifiers = vector.offset(
    &tokenizer.modifiers,
    start,
  ) or_return

  advance(tokenizer) or_return
  for assert_type(tokenizer, Identifier) == nil {
    parse_type(tokenizer) or_return

    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Semicolon) or_return

    advance(tokenizer) or_return
  }

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceClose) or_return

  advance(tokenizer) or_return

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Semicolon) or_return

  return nil
}

@(private)
parse_interpret_property :: proc(tokenizer: ^Tokenizer) -> error.Error {
  assert_symbol(tokenizer, .Dot) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return

  property := cast([]u8)(tokenizer.token.(Identifier))

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier)
  if eql(property, use_mod_map_mods_word[:]) {
    tokenizer.compatibility.default_mods = tokenizer.token.(Identifier)
  } else if eql(property, repeat_word[:]) {
    repeat := cast([]u8)(tokenizer.token.(Identifier))
    tokenizer.compatibility.default_repeat = eql(repeat, true_word[:])
  } else {
    return .TypeAssertionFailed
  }

  return nil
}

@(private)
match_kind_from_bytes :: proc(
  bytes: []u8,
) -> Xkb_Compatibility_Interpret_Match_Kind {
  if eql(bytes, any_of_word[:]) {
    return .AnyOf
  } else if eql(bytes, exactly_word[:]) {
    return .Exactly
  } else if eql(bytes, any_of_or_none_word[:]) {
    return .AnyOfOrNone
  }

  return nil
}

@(private)
parse_interpret_match :: proc(
  tokenizer: ^Tokenizer,
) -> (
  match: Xkb_Compatibility_Interpret_Match,
  err: error.Error,
) {
  assert_type(tokenizer, Identifier) or_return

  match.key = code_from_bytes(
    tokenizer,
    cast([]u8)(tokenizer.token.(Identifier)),
  )

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Plus) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return
  match.kind = match_kind_from_bytes(cast([]u8)(tokenizer.token.(Identifier)))

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .ParenOpen) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return

  start := tokenizer.modifiers.len
  parse_modifier_combination(tokenizer) or_return
  match.modifiers = vector.offset(&tokenizer.modifiers, start) or_return

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .ParenClose) or_return

  advance(tokenizer) or_return

  return match, nil
}

@(private)
parse_interpret_mods :: proc(
  tokenizer: ^Tokenizer,
) -> (
  mods: Identifier,
  err: error.Error,
) {
  assert_type(tokenizer, Identifier) or_return

  return tokenizer.token.(Identifier), nil
}

@(private)
parse_interpret_action_arguments :: proc(
  tokenizer: ^Tokenizer,
) -> error.Error {
  advance(tokenizer) or_return

  for assert_type(tokenizer, Symbol) == nil &&
      assert_symbol(tokenizer, .Comma) == nil {
    advance(tokenizer) or_return

    assert_type(tokenizer, Identifier) or_return
    vector.append(
      &tokenizer.identifiers,
      tokenizer.token.(Identifier),
    ) or_return
    advance(tokenizer) or_return

  }
  return nil
}

@(private)
parse_interpret_action_mods :: proc(
  tokenizer: ^Tokenizer,
) -> (
  mods: Xkb_Compatibility_Action_Mods,
  err: error.Error,
) {
  ok: bool

  assert_type(tokenizer, Identifier) or_return
  assert_identifier(tokenizer, Identifier(modifiers_word[:])) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return
  mods.modifiers, ok = modifier_from_bytes(
    cast([]u8)(tokenizer.token.(Identifier)),
  )

  if !ok {
    // return mods, .ModifierNotFound
  }

  start := tokenizer.identifiers.len
  parse_interpret_action_arguments(tokenizer) or_return
  mods.attributes = vector.offset(&tokenizer.identifiers, start) or_return

  return mods, nil
}

@(private)
parse_interpret_action_group :: proc(
  tokenizer: ^Tokenizer,
) -> (
  group: Xkb_Compatibility_Action_Group,
  err: error.Error,
) {
  assert_type(tokenizer, Identifier) or_return
  assert_identifier(tokenizer, Identifier(group_word[:])) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  group.value = parse_integer(tokenizer) or_return
  advance(tokenizer) or_return

  return group, nil
}

@(private)
parse_interpret_action_controls :: proc(
  tokenizer: ^Tokenizer,
) -> (
  controls: Xkb_Compatibility_Action_Controls,
  err: error.Error,
) {
  assert_type(tokenizer, Identifier) or_return
  assert_identifier(tokenizer, Identifier(controls_word[:])) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return
  controls.value = tokenizer.token.(Identifier)

  advance(tokenizer) or_return

  return controls, nil
}

parse_interpret_action_ptr :: proc(
  tokenizer: ^Tokenizer,
) -> (
  ptr: Xkb_Compatibility_Action_Ptr,
  err: error.Error,
) {
  outer: for assert_type(tokenizer, Identifier) == nil {
    property := cast([]u8)(tokenizer.token.(Identifier))

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Equal) or_return

    advance(tokenizer) or_return
    if eql(property, button_word[:]) {
      b, e := parse_integer(tokenizer)
      if e != nil {
        ptr.button = 0
      } else {
        ptr.button = b
      }
    } else if eql(property, affect_word[:]) {
      assert_type(tokenizer, Identifier) or_return
      ptr.affect = tokenizer.token.(Identifier)
    } else if eql(property, count_word[:]) {
      assert_type(tokenizer, Identifier) or_return
      ptr.count = to_number(tokenizer.token.(Identifier)) or_return
    }

    advance(tokenizer)
    assert_type(tokenizer, Symbol) or_return

    #partial switch tokenizer.token.(Symbol) {
    case .ParenClose:
      break outer
    }

    assert_symbol(tokenizer, .Comma) or_return
    advance(tokenizer) or_return
  }

  return ptr, nil
}

@(private)
parse_integer :: proc(tokenizer: ^Tokenizer) -> (i: i32, err: error.Error) {
  if assert_type(tokenizer, Symbol) == nil {
    symbol := tokenizer.token.(Symbol)

    advance(tokenizer) or_return
    assert_type(tokenizer, Identifier) or_return
    i = i32(to_number(tokenizer.token.(Identifier)) or_return)

    if symbol == .Minus {
      i *= -1
    }
  } else {
    assert_type(tokenizer, Identifier) or_return
    i = i32(to_number(tokenizer.token.(Identifier)) or_return)
  }

  return i, nil
}

@(private)
parse_interpret_private :: proc(
  tokenizer: ^Tokenizer,
) -> (
  private: Xkb_Compatibility_Action_Private,
  err: error.Error,
) {
  assert_type(tokenizer, Identifier) or_return
  assert_identifier(tokenizer, Identifier(type_word[:])) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return
  private.kind = tokenizer.token.(Identifier)

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Comma) or_return

  start := tokenizer.identifiers.len
  advance(tokenizer) or_return
  for assert_type(tokenizer, Identifier) == nil {
    assert_identifier(tokenizer, Identifier(data_word[:])) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .SquareOpen) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Identifier) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .SquareClose) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Equal) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Identifier) or_return
    vector.append(
      &tokenizer.identifiers,
      tokenizer.token.(Identifier),
    ) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return

    if tokenizer.token.(Symbol) != .Comma {
      break
    }

    advance(tokenizer) or_return
  }

  private.data = vector.offset(&tokenizer.identifiers, start) or_return

  return private, nil
}

@(private)
parse_interpret_move_ptr :: proc(
  tokenizer: ^Tokenizer,
) -> (
  move_ptr: Xkb_Compatibility_Action_MovePtr,
  err: error.Error,
) {
  assert_type(tokenizer, Identifier) or_return
  assert_identifier(tokenizer, Identifier(x_word[:])) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  move_ptr.x = parse_integer(tokenizer) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Comma) or_return

  advance(tokenizer) or_return
  assert_identifier(tokenizer, Identifier(y_word[:])) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  move_ptr.y = parse_integer(tokenizer) or_return

  advance(tokenizer) or_return

  return move_ptr, nil

}

@(private)
parse_interpret_switch_screen :: proc(
  tokenizer: ^Tokenizer,
) -> (
  screen: Xkb_Compatibility_Action_SwitchScreen,
  err: error.Error,
) {
  assert_type(tokenizer, Identifier) or_return
  assert_identifier(tokenizer, Identifier(screen_word[:])) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return

  screen.value = to_number(tokenizer.token.(Identifier)) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Comma) or_return

  advance(tokenizer) or_return
  screen.same = assert_type(tokenizer, Symbol) == nil

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return
  assert_identifier(tokenizer, Identifier(same_word[:])) or_return

  advance(tokenizer) or_return

  return screen, nil
}


@(private)
parse_interpret_action :: proc(
  tokenizer: ^Tokenizer,
) -> (
  action: Xkb_Compatibility_Interpret_Action,
  err: error.Error,
) {
  ok: bool

  assert_type(tokenizer, Identifier) or_return
  kind := cast([]u8)(tokenizer.token.(Identifier))

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .ParenOpen) or_return

  advance(tokenizer) or_return
  if eql(kind, lock_mods_word[:]) {
    action = Xkb_Compatibility_Action_LockMods(
      parse_interpret_action_mods(tokenizer) or_return,
    )
  } else if eql(kind, latch_mods_word[:]) {
    action = Xkb_Compatibility_Action_LatchMods(
      parse_interpret_action_mods(tokenizer) or_return,
    )
  } else if eql(kind, set_mods_word[:]) {
    action = Xkb_Compatibility_Action_SetMods(
      parse_interpret_action_mods(tokenizer) or_return,
    )
  } else if eql(kind, lock_group_word[:]) {
    action = Xkb_Compatibility_Action_LockGroup(
      parse_interpret_action_group(tokenizer) or_return,
    )
  } else if eql(kind, latch_group_word[:]) {
    action = Xkb_Compatibility_Action_LatchGroup(
      parse_interpret_action_group(tokenizer) or_return,
    )
  } else if eql(kind, set_group_word[:]) {
    action = Xkb_Compatibility_Action_SetGroup(
      parse_interpret_action_group(tokenizer) or_return,
    )
  } else if eql(kind, lock_controls_word[:]) {
    action = Xkb_Compatibility_Action_LockControls(
      parse_interpret_action_controls(tokenizer) or_return,
    )
  } else if eql(kind, latch_controls_word[:]) {
    action = Xkb_Compatibility_Action_LatchControls(
      parse_interpret_action_controls(tokenizer) or_return,
    )
  } else if eql(kind, set_controls_word[:]) {
    action = Xkb_Compatibility_Action_SetControls(
      parse_interpret_action_controls(tokenizer) or_return,
    )
  } else if eql(kind, set_ptr_dflt_word[:]) {
    action = Xkb_Compatibility_Action_SetPtr(
      parse_interpret_action_ptr(tokenizer) or_return,
    )
  } else if eql(kind, lock_ptr_btn_word[:]) {
    action = Xkb_Compatibility_Action_LockPtrBtn(
      parse_interpret_action_ptr(tokenizer) or_return,
    )
  } else if eql(kind, ptr_btn_word[:]) {
    action = Xkb_Compatibility_Action_PtrBtn(
      parse_interpret_action_ptr(tokenizer) or_return,
    )
  } else if eql(kind, terminate_word[:]) {
    action = Xkb_Compatibility_Action_Terminate({})
  } else if eql(kind, move_ptr_word[:]) {
    action = parse_interpret_move_ptr(tokenizer) or_return
  } else if eql(kind, switch_screen_word[:]) {
    action = parse_interpret_switch_screen(tokenizer) or_return
  } else if eql(kind, private_word[:]) {
    action = parse_interpret_private(tokenizer) or_return
  } else {
    log.error("Failed to parse action:", string(kind))
    return action, .TypeAssertionFailed
  }

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .ParenClose) or_return

  return action, nil
}

@(private)
parse_interpret :: proc(tokenizer: ^Tokenizer) -> error.Error {
  ok: bool
  interpret: Xkb_Compatibility_Interpret
  interpret.match = parse_interpret_match(tokenizer) or_return
  interpret.action = nil
  interpret.repeat = tokenizer.compatibility.default_repeat
  interpret.mods = tokenizer.compatibility.default_mods

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceOpen) or_return

  advance(tokenizer) or_return
  for assert_type(tokenizer, Identifier) == nil {
    property := cast([]u8)(tokenizer.token.(Identifier))

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Equal) or_return

    advance(tokenizer) or_return
    if eql(property, virtual_modifier_word[:]) {
      interpret.modifier, ok = modifier_from_bytes(
        cast([]u8)(tokenizer.token.(Identifier)),
      )
    } else if eql(property, action_word[:]) {
      interpret.action = parse_interpret_action(tokenizer) or_return
    } else if eql(property, use_mod_map_mods_word[:]) {
      interpret.mods = parse_interpret_mods(tokenizer) or_return
    } else if eql(property, repeat_word[:]) {
      interpret.repeat =
        assert_identifier(tokenizer, Identifier(true_word[:])) == nil
    }

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Semicolon) or_return

    advance(tokenizer) or_return
  }

  vector.append(&tokenizer.xkb_interprets, interpret) or_return

  return nil
}

@(private)
parse_indicator :: proc(tokenizer: ^Tokenizer) -> error.Error {
  assert_type(tokenizer, String) or_return
  ok: bool

  indicator: Xkb_Compatibility_Indicator
  indicator.name = tokenizer.token.(String)

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceOpen) or_return

  advance(tokenizer) or_return
  for assert_type(tokenizer, Identifier) == nil {
    property := cast([]u8)(tokenizer.token.(Identifier))

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Equal) or_return

    advance(tokenizer) or_return
    if eql(property, modifiers_word[:]) {
      assert_type(tokenizer, Identifier) or_return
      indicator.modifier, ok = modifier_from_bytes(
        cast([]u8)(tokenizer.token.(Identifier)),
      )
    } else if eql(property, which_mod_state_word[:]) {
      assert_type(tokenizer, Identifier) or_return
      indicator.state = tokenizer.token.(Identifier)
    } else if eql(property, groups_word[:]) {
      assert_type(tokenizer, Identifier) or_return
      indicator.groups = tokenizer.token.(Identifier)
    } else if eql(property, controls_word[:]) {
      assert_type(tokenizer, Identifier) or_return
      indicator.controls = tokenizer.token.(Identifier)
    }

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Semicolon) or_return

    advance(tokenizer) or_return
  }

  vector.append(&tokenizer.xkb_indicators, indicator) or_return

  return nil
}

@(private)
parse_compatibility :: proc(
  tokenizer: ^Tokenizer,
  allocator: runtime.Allocator,
) -> error.Error {
  advance(tokenizer) or_return
  assert_type(tokenizer, String) or_return
  tokenizer.compatibility.name = tokenizer.token.(String)

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceOpen) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return
  assert_identifier(tokenizer, Identifier(virtual_modifiers_word[:])) or_return

  start := tokenizer.modifiers.len
  advance(tokenizer) or_return
  outer: for assert_type(tokenizer, Identifier) == nil {
    modifier, ok := modifier_from_bytes(
      cast([]u8)(tokenizer.token.(Identifier)),
    )

    if !ok {
      return .ModifierNotFound
    }

    vector.append(&tokenizer.modifiers, modifier) or_return
    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return

    #partial switch tokenizer.token.(Symbol) {
    case .Comma:
      advance(tokenizer) or_return
    case:
      break outer
    }
  }

  tokenizer.types.modifiers = vector.offset(
    &tokenizer.modifiers,
    start,
  ) or_return
  interpret_start := tokenizer.xkb_interprets.len
  indicator_start := tokenizer.xkb_indicators.len

  advance(tokenizer) or_return
  for assert_type(tokenizer, Identifier) == nil {
    word := cast([]u8)(tokenizer.token.(Identifier))

    if eql(word, interpret[:]) {
      advance(tokenizer) or_return

      #partial switch _ in tokenizer.token {
      case Identifier:
        parse_interpret(tokenizer) or_return
      case Symbol:
        assert_symbol(tokenizer, .Dot) or_return
        parse_interpret_property(tokenizer) or_return
      case:
        return .TypeAssertionFailed
      }
    } else if eql(word, indicator[:]) {
      advance(tokenizer) or_return
      parse_indicator(tokenizer) or_return
    } else {
      return .TypeAssertionFailed
    }

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Semicolon) or_return
    advance(tokenizer) or_return
  }

  tokenizer.compatibility.interprets = vector.offset(
    &tokenizer.xkb_interprets,
    interpret_start,
  ) or_return
  tokenizer.compatibility.indicators = vector.offset(
    &tokenizer.xkb_indicators,
    indicator_start,
  ) or_return

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceClose) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Semicolon) or_return

  return nil
}

@(private)
parse_key :: proc(
  tokenizer: ^Tokenizer,
  is_array: bool,
  allocator: runtime.Allocator,
) -> error.Error {
  pair: Xkb_Symbols_Pair

  assert_type(tokenizer, Name) or_return
  pair.key = key_pair_from_bytes(([]u8)(tokenizer.token.(Name)))
  start := tokenizer.codes.len

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceOpen) or_return

  advance(tokenizer) or_return

  #partial switch _ in tokenizer.token {
  case Identifier:
    assert_identifier(tokenizer, Identifier(type_word[:])) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Equal) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, String) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Comma) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Identifier) or_return
    assert_identifier(tokenizer, Identifier(symbols_word[:])) or_return

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .SquareOpen)
    advance(tokenizer) or_return

    index := tokenizer.token.(Identifier)

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .SquareClose)

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Equal)
    advance(tokenizer) or_return

    assert_symbol(tokenizer, .SquareOpen) or_return

    advance(tokenizer) or_return

    parse_key_symbols(tokenizer) or_return

    assert_symbol(tokenizer, .SquareClose) or_return
    advance(tokenizer) or_return
  case Symbol:
    assert_symbol(tokenizer, .SquareOpen) or_return

    advance(tokenizer) or_return
    parse_key_symbols(tokenizer) or_return

    assert_symbol(tokenizer, .SquareClose) or_return
    advance(tokenizer) or_return
  }

  pair.codes = vector.offset(&tokenizer.codes, start) or_return

  if tokenizer.codes.len > start {
    vector.append(&tokenizer.pairs, pair) or_return
  }

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceClose) or_return

  return nil
}

@(private)
parse_modifier_map :: proc(tokenizer: ^Tokenizer) -> error.Error {
  ok: bool
  symbols_map: Xkb_Symbols_Map

  assert_type(tokenizer, Identifier) or_return
  symbols_map.modifier, ok = modifier_from_bytes(
    cast([]u8)(tokenizer.token.(Identifier)),
  )

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceOpen) or_return

  start := tokenizer.numbers.len

  advance(tokenizer) or_return
  for assert_type(tokenizer, Name) == nil {
    vector.append(
      &tokenizer.numbers,
      key_pair_from_bytes(([]u8)(tokenizer.token.(Name))),
    ) or_return

    advance(tokenizer) or_return

    assert_type(tokenizer, Symbol) or_return
    if tokenizer.token.(Symbol) == .BraceClose do break

    assert_symbol(tokenizer, .Comma) or_return
    advance(tokenizer) or_return
  }

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceClose) or_return

  symbols_map.codes = vector.offset(&tokenizer.numbers, start) or_return

  vector.append(&tokenizer.maps, symbols_map) or_return

  return nil
}

@(private)
parse_key_symbols :: proc(tokenizer: ^Tokenizer) -> error.Error {
  for assert_type(tokenizer, Identifier) == nil {
    code := code_from_bytes(
      tokenizer,
      cast([]u8)(tokenizer.token.(Identifier)),
    )

    if code != nil {
      vector.append(&tokenizer.codes, code) or_return
    }

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return

    if tokenizer.token.(Symbol) != .Comma {
      break
    }

    advance(tokenizer) or_return
  }


  return nil
}

@(private)
parse_symbols :: proc(
  tokenizer: ^Tokenizer,
  allocator: runtime.Allocator,
) -> error.Error {
  advance(tokenizer) or_return
  assert_type(tokenizer, String) or_return
  tokenizer.symbols.name = tokenizer.token.(String)

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol)
  assert_symbol(tokenizer, .BraceOpen) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return
  assert_identifier(tokenizer, Identifier(name_word[:])) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .SquareOpen) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Identifier) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .SquareClose) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Equal) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, String) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Semicolon) or_return

  pairs_start := tokenizer.pairs.len
  maps_start := tokenizer.maps.len

  advance(tokenizer) or_return
  for assert_type(tokenizer, Identifier) == nil {
    iden := cast([]u8)(tokenizer.token.(Identifier))
    advance(tokenizer) or_return

    if eql(iden, key_word[:]) {
      parse_key(tokenizer, false, allocator) or_return
    } else if eql(iden, modifier_map_word[:]) {
      parse_modifier_map(tokenizer) or_return
    } else {
      return .TypeAssertionFailed
    }

    advance(tokenizer) or_return
    assert_type(tokenizer, Symbol) or_return
    assert_symbol(tokenizer, .Semicolon) or_return

    advance(tokenizer) or_return
  }

  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .BraceClose) or_return

  advance(tokenizer) or_return
  assert_type(tokenizer, Symbol) or_return
  assert_symbol(tokenizer, .Semicolon) or_return

  tokenizer.symbols.maps = vector.offset(&tokenizer.maps, maps_start) or_return
  tokenizer.symbols.pairs = vector.offset(
    &tokenizer.pairs,
    pairs_start,
  ) or_return

  return nil
}

@(private)
assert_identifier :: proc(
  tokenizer: ^Tokenizer,
  identifier: Identifier,
  loc := #caller_location,
) -> error.Error {
  if !eql(([]u8)(tokenizer.token.(Identifier)), ([]u8)(identifier)) {
    return .IdentifierAssertionFailed
  }

  return nil
}

@(private)
assert_keyword :: proc(
  tokenizer: ^Tokenizer,
  keyword: Keyword,
  loc := #caller_location,
) -> error.Error {
  if tokenizer.token.(Keyword) != keyword {
    return .KeywordAssertionFailed
  }

  return nil

}

@(private)
assert_symbol :: proc(
  tokenizer: ^Tokenizer,
  symbol: Symbol,
  loc := #caller_location,
) -> error.Error {
  if tokenizer.token.(Symbol) != symbol {
    return .SymbolAssertionFailed
  }

  return nil
}

@(private)
assert_type :: proc(
  tokenizer: ^Tokenizer,
  $T: typeid,
  loc := #caller_location,
) -> error.Error {
  t, ok := tokenizer.token.(T)

  if !ok {
    return .TypeAssertionFailed
  }

  return nil
}

@(private)
advance :: proc(
  tokenizer: ^Tokenizer,
  loc := #caller_location,
) -> error.Error {
  tokenizer.token = next(tokenizer)

  if tokenizer.token == nil {
    return .InvalidToken
  }

  return nil
}

@(private)
next :: proc(tokenizer: ^Tokenizer) -> Token {
  skip_whitespace(tokenizer)

  if at_end(tokenizer) do return .Eof

  if is_ascci(tokenizer.bytes[tokenizer.offset]) {
    start := tokenizer.offset
    for !at_end(tokenizer) && is_ascci(tokenizer.bytes[tokenizer.offset]) {
      tokenizer.offset += 1
    }

    bytes := tokenizer.bytes[start:tokenizer.offset]

    if keyword := get_keyword(bytes); keyword != nil do return keyword.?

    return Identifier(bytes)
  } else {
    start := tokenizer.offset
    tokenizer.offset += 1

    switch tokenizer.bytes[start] {
    case '<':
      for !at_end(tokenizer) && tokenizer.bytes[tokenizer.offset] != '>' {
        tokenizer.offset += 1
      }

      defer tokenizer.offset += 1
      return Name(tokenizer.bytes[start + 1:tokenizer.offset])
    case '(':
      return .ParenOpen
    case ')':
      return .ParenClose
    case '{':
      return .BraceOpen
    case '}':
      return .BraceClose
    case '[':
      return .SquareOpen
    case ']':
      return .SquareClose
    case ';':
      return .Semicolon
    case ',':
      return .Comma
    case '-':
      return .Minus
    case '+':
      return .Plus
    case '.':
      return .Dot
    case '=':
      return .Equal
    case '!':
      return .Bang
    case '"':
      start = tokenizer.offset

      for !at_end(tokenizer) && tokenizer.bytes[tokenizer.offset] != '"' {
        tokenizer.offset += 1
      }

      defer tokenizer.offset += 1
      return String(tokenizer.bytes[start:tokenizer.offset])
    case:
      log.error("Wired char:", rune(tokenizer.bytes[start]))
    }
  }

  return nil
}

@(private)
skip_whitespace :: proc(tokenizer: ^Tokenizer) {
  for !at_end(tokenizer) && tokenizer.bytes[tokenizer.offset] == '\n' {
    tokenizer.line += 1
    tokenizer.offset += 1
  }

  for !at_end(tokenizer) &&
      (tokenizer.bytes[tokenizer.offset] == ' ' ||
          tokenizer.bytes[tokenizer.offset] == '\t') {
    tokenizer.offset += 1
  }
}

@(private)
get_keyword :: proc(bytes: []u8) -> Maybe(Keyword) {
  if eql(xkb_keymap[:], bytes) do return .Keymap
  if eql(xkb_keycodes[:], bytes) do return .Keycodes
  if eql(xkb_types[:], bytes) do return .Types
  if eql(xkb_compatibility[:], bytes) do return .Compatibility
  if eql(xkb_symbols[:], bytes) do return .Symbols

  return nil
}

eql :: proc(first: []u8, second: []u8) -> bool {
  if len(first) != len(second) do return false

  for i in 0 ..< len(first) {
    if first[i] != second[i] do return false
  }

  return true
}

@(private)
at_end :: proc(tokenizer: ^Tokenizer) -> bool {
  return tokenizer.offset >= u32(len(tokenizer.bytes))
}

@(private)
is_number :: proc(u: u8) -> bool {
  return u >= '0' && u <= '9'
}

@(private)
to_number :: proc(bytes: Identifier) -> (u32, error.Error) {
  number: u32

  for b in bytes {
    if !is_number(b) do return 0, .NotANumber
    number *= 10
    number += u32(b) - '0'
  }

  return number, nil
}

@(private)
is_ascci :: proc(u: u8) -> bool {
  return is_lower_ascci(u) || is_upper_ascci(u) || is_number(u) || u == '_'
}

@(private)
is_lower_ascci :: proc(u: u8) -> bool {
  return u >= 'a' && u <= 'z'
}

@(private)
is_upper_ascci :: proc(u: u8) -> bool {
  return u >= 'A' && u <= 'Z'
}

@(private)
code_from_bytes :: proc(tokenizer: ^Tokenizer, bytes: []u8) -> Code {
  code := tokenizer.code_equivalent[string(bytes)]
  return code
}

Code :: enum {
  Escape = 27,
  Space = 32,
  Exclamation,
  DoubleQuote,
  NumberSign,
  DolarSign,
  Percent,
  AsciiCircum,
  Asterisk,
  ParenLeft,
  ParenRight,
  Star,
  Plus,
  Comma,
  Minus,
  Dot,
  Bar,
  Zero,
  One,
  Two,
  Three,
  Four,
  Five,
  Six,
  Seven,
  Eight,
  Nine,
  Colon,
  Semicolon,
  Less,
  Equal,
  Greater,
  QuestioMark,
  At,
  A,
  B,
  C,
  D,
  E,
  F,
  G,
  H,
  I,
  J,
  K,
  L,
  M,
  N,
  O,
  P,
  Q,
  R,
  S,
  T,
  U,
  V,
  W,
  X,
  Y,
  Z,
  SquareLeft,
  CounterBar,
  SquareRight,
  Hat,
  Underscore,
  Grave,
  a,
  b,
  c,
  d,
  e,
  f,
  g,
  h,
  i,
  j,
  k,
  l,
  m,
  n,
  o,
  p,
  q,
  r,
  s,
  t,
  u,
  v,
  w,
  x,
  y,
  z,
  CurlyLeft,
  Pipe,
  CurlyRight,
  Tilde,
  Del,
  Return,
  ArrowUp,
  ArrowDown,
  ArrowLeft,
  ArrowRight,
}

@(private)
key_word := [?]u8{'k', 'e', 'y'}
@(private)
type_word := [?]u8{'t', 'y', 'p', 'e'}
@(private)
data_word := [?]u8{'d', 'a', 't', 'a'}
@(private)
name_word := [?]u8{'n', 'a', 'm', 'e'}
@(private)
symbols_word := [?]u8{'s', 'y', 'm', 'b', 'o', 'l', 's'}
@(private)
modifier_map_word := [?]u8 {
  'm',
  'o',
  'd',
  'i',
  'f',
  'i',
  'e',
  'r',
  '_',
  'm',
  'a',
  'p',
}

@(private)
numlock_word := [?]u8{'N', 'u', 'm', 'L', 'o', 'c', 'k'}
@(private)
alt_word := [?]u8{'A', 'l', 't'}
@(private)
level_three_word := [?]u8{'L', 'e', 'v', 'e', 'l', 'T', 'h', 'r', 'e', 'e'}
@(private)
super_word := [?]u8{'S', 'u', 'p', 'e', 'r'}
@(private)
level_five_word := [?]u8{'L', 'e', 'v', 'e', 'l', 'F', 'i', 'v', 'e'}
@(private)
meta_word := [?]u8{'M', 'e', 't', 'a'}
@(private)
hyper_word := [?]u8{'H', 'y', 'p', 'e', 'r'}
@(private)
scroll_lock_word := [?]u8{'S', 'c', 'r', 'o', 'l', 'l', 'L', 'o', 'c', 'k'}
@(private)
shift_word := [?]u8{'S', 'h', 'i', 'f', 't'}
@(private)
control_word := [?]u8{'C', 'o', 'n', 't', 'r', 'o', 'l'}
@(private)
lock_word := [?]u8{'L', 'o', 'c', 'k'}

@(private)
lock_mods_word := [?]u8{'L', 'o', 'c', 'k', 'M', 'o', 'd', 's'}
@(private)
latch_mods_word := [?]u8{'L', 'a', 't', 'c', 'h', 'M', 'o', 'd', 's'}
@(private)
set_mods_word := [?]u8{'S', 'e', 't', 'M', 'o', 'd', 's'}
@(private)
lock_group_word := [?]u8{'L', 'o', 'c', 'k', 'G', 'r', 'o', 'u', 'p'}
@(private)
latch_group_word := [?]u8{'L', 'a', 't', 'c', 'h', 'G', 'r', 'o', 'u', 'p'}
@(private)
set_group_word := [?]u8{'S', 'e', 't', 'G', 'r', 'o', 'u', 'p'}
@(private)
lock_controls_word := [?]u8 {
  'L',
  'o',
  'c',
  'k',
  'C',
  'o',
  'n',
  't',
  'r',
  'o',
  'l',
  's',
}
@(private)
latch_controls_word := [?]u8 {
  'L',
  'a',
  't',
  'c',
  'h',
  'C',
  'o',
  'n',
  't',
  'r',
  'o',
  'l',
  's',
}
@(private)
set_controls_word := [?]u8 {
  'S',
  'e',
  't',
  'C',
  'o',
  'n',
  't',
  'r',
  'o',
  'l',
  's',
}
@(private)
set_ptr_dflt_word := [?]u8{'S', 'e', 't', 'P', 't', 'r', 'D', 'f', 'l', 't'}
@(private)
lock_ptr_btn_word := [?]u8{'L', 'o', 'c', 'k', 'P', 't', 'r', 'B', 't', 'n'}
@(private)
ptr_btn_word := [?]u8{'P', 't', 'r', 'B', 't', 'n'}
@(private)
terminate_word := [?]u8{'T', 'e', 'r', 'm', 'i', 'n', 'a', 't', 'e'}
@(private)
move_ptr_word := [?]u8{'M', 'o', 'v', 'e', 'P', 't', 'r'}
@(private)
switch_screen_word := [?]u8 {
  'S',
  'w',
  'i',
  't',
  'c',
  'h',
  'S',
  'c',
  'r',
  'e',
  'e',
  'n',
}
@(private)
private_word := [?]u8{'P', 'r', 'i', 'v', 'a', 't', 'e'}
@(private)
screen_word := [?]u8{'s', 'c', 'r', 'e', 'e', 'n'}
@(private)
same_word := [?]u8{'s', 'a', 'm', 'e'}
@(private)
x_word := [?]u8{'x'}
@(private)
y_word := [?]u8{'y'}

@(private)
modifiers_word := [?]u8{'m', 'o', 'd', 'i', 'f', 'i', 'e', 'r', 's'}
@(private)
which_mod_state_word := [?]u8 {
  'w',
  'h',
  'i',
  'c',
  'h',
  'M',
  'o',
  'd',
  'S',
  't',
  'a',
  't',
  'e',
}
@(private)
groups_word := [?]u8{'g', 'r', 'o', 'u', 'p', 's'}
@(private)
group_word := [?]u8{'g', 'r', 'o', 'u', 'p'}
@(private)
controls_word := [?]u8{'c', 'o', 'n', 't', 'r', 'o', 'l', 's'}
@(private)
button_word := [?]u8{'b', 'u', 't', 't', 'o', 'n'}
@(private)
affect_word := [?]u8{'a', 'f', 'f', 'e', 'c', 't'}
@(private)
count_word := [?]u8{'c', 'o', 'u', 'n', 't'}
@(private)
preserve_word := [?]u8{'p', 'r', 'e', 's', 'e', 'r', 'v', 'e'}
@(private)
map_word := [?]u8{'m', 'a', 'p'}
@(private)
level_name_word := [?]u8{'l', 'e', 'v', 'e', 'l', '_', 'n', 'a', 'm', 'e'}

@(private)
minimum_word := [?]u8{'m', 'i', 'n', 'i', 'm', 'u', 'm'}
@(private)
maximum_word := [?]u8{'m', 'a', 'x', 'i', 'm', 'u', 'm'}
@(private)
any_of_word := [?]u8{'a', 'n', 'y', 'O', 'f'}
@(private)
any_of_or_none_word := [?]u8 {
  'a',
  'n',
  'y',
  'O',
  'f',
  'O',
  'r',
  'N',
  'o',
  'n',
  'e',
}
@(private)
exactly_word := [?]u8{'E', 'x', 'a', 'c', 't', 'l', 'y'}
@(private)
interpret := [?]u8{'i', 'n', 't', 'e', 'r', 'p', 'r', 'e', 't'}
@(private)
alias := [?]u8{'a', 'l', 'i', 'a', 's'}
@(private)
indicator := [?]u8{'i', 'n', 'd', 'i', 'c', 'a', 't', 'o', 'r'}
@(private)
action_word := [?]u8{'a', 'c', 't', 'i', 'o', 'n'}
@(private)
true_word := [?]u8{'T', 'r', 'u', 'e'}
@(private)
use_mod_map_mods_word := [?]u8 {
  'u',
  's',
  'e',
  'M',
  'o',
  'd',
  'M',
  'a',
  'p',
  'M',
  'o',
  'd',
  's',
}
@(private)
virtual_modifier_word := [?]u8 {
  'v',
  'i',
  'r',
  't',
  'u',
  'a',
  'l',
  'M',
  'o',
  'd',
  'i',
  'f',
  'i',
  'e',
  'r',
}
@(private)
repeat_word := [?]u8{'r', 'e', 'p', 'e', 'a', 't'}
@(private)
virtual_modifiers_word := [?]u8 {
  'v',
  'i',
  'r',
  't',
  'u',
  'a',
  'l',
  '_',
  'm',
  'o',
  'd',
  'i',
  'f',
  'i',
  'e',
  'r',
  's',
}
@(private)
xkb_keymap := [?]u8{'x', 'k', 'b', '_', 'k', 'e', 'y', 'm', 'a', 'p'}
@(private)
xkb_keycodes := [?]u8 {
  'x',
  'k',
  'b',
  '_',
  'k',
  'e',
  'y',
  'c',
  'o',
  'd',
  'e',
  's',
}
@(private)
xkb_types := [?]u8{'x', 'k', 'b', '_', 't', 'y', 'p', 'e', 's'}
@(private)
xkb_symbols := [?]u8{'x', 'k', 'b', '_', 's', 'y', 'm', 'b', 'o', 'l', 's'}
@(private)
xkb_compatibility := [?]u8 {
  'x',
  'k',
  'b',
  '_',
  'c',
  'o',
  'm',
  'p',
  'a',
  't',
  'i',
  'b',
  'i',
  'l',
  'i',
  't',
  'y',
}

@(test)
keycodes_parse_test :: proc(t: ^testing.T) {
  ok: bool
  bytes: []u8
  keymap: Keymap_Context

  err: error.Error
  content := `xkb_keymap {
    xkb_keycodes "(unnamed)" {
      minimum = 8;
      maximum = 708;
      <ESC>    = 9;
      <AE01>         = 10;
      <AE02>         = 11;
      <AE03>         = 12;
      <AE04>         = 13;
    };
  };`


  _, err = parse_keymap(transmute([]u8)(content), context.allocator)

  testing.expect(t, err == nil, "AN ERROR OCCOURED")
}

@(test)
symbols_parse_test :: proc(t: ^testing.T) {
  bytes: []u8
  keymap: Keymap_Context

  err: error.Error
  content := `xkb_keymap {
    xkb_symbols "(unnamed)" {
        name[Group1]="English (US)";

      key <ESC>    {      [    Escape ] };
      key <AE01>         {      [         1,    exclam ] };
      key <AE02>         {      [         2,        at ] };
      key <AE03>         {      [         3,      numbersign ] };
      key <AE04>         {      [         4,    dollar ] };
      key <AE05>         {      [         5,   percent ] };
      key <AE06>         {      [         6,     asciicircum ] };
      key <AE07>         {      [         7,       ampersand ] };
      key <AE08>         {      [         8,  asterisk ] };
      key <AE09>         {      [         9,       parenleft ] };
      key <AE10>         {      [         0,      parenright ] };
      key <AE11>         {      [     minus,      underscore ] };
      key <AE12>         {      [     equal,      plus ] };
      key <BKSP>         {      [       BackSpace,       BackSpace ] };
       };
    };`


  _, err = parse_keymap(transmute([]u8)(content), context.allocator)

  testing.expect(t, err == nil, "AN ERROR OCCOURED")
}


@(test)
compatibility_parse_test :: proc(t: ^testing.T) {
  bytes: []u8
  tokenizer: Tokenizer

  err: error.Error
  content := `xkb_keymap {
    xkb_compatibility "(unnamed)" {
      virtual_modifiers NumLock,Alt,LevelThree,Super,LevelFive,Meta,Hyper,ScrollLock;

      interpret.useModMapMods= AnyLevel;
      interpret.repeat= False;
      interpret ISO_Level2_Latch+Exactly(Shift) {
        useModMapMods=level1;
        action= LatchMods(modifiers=Shift,clearLocks,latchToLock);
        repeat= True;
      };
      indicator "Shift Lock" {
        whichModState= locked;
        modifiers= Shift;
        groups= 0xfe;
        controls= MouseKeys;
      };
      interpret Shift_Lock+AnyOf(Shift+Lock) {
        action= LockMods(modifiers=Shift);
      };
      interpret Num_Lock+AnyOf(all) {
        virtualModifier= NumLock;
        action= LockMods(modifiers=NumLock);
      };
      interpret ISO_Level3_Shift+AnyOf(all) {
        virtualModifier= LevelThree;
        useModMapMods=level1;
        action= SetMods(modifiers=LevelThree,clearLocks);
      };
      interpret ISO_Level3_Latch+AnyOf(all) {
        virtualModifier= LevelThree;
        useModMapMods=level1;
        action= LatchMods(modifiers=LevelThree,clearLocks,latchToLock);
      };
      interpret ISO_Level3_Lock+AnyOf(all) {
        virtualModifier= LevelThree;
        useModMapMods=level1;
        action= LockMods(modifiers=LevelThree);
      };
      interpret Alt_L+AnyOf(all) {
        virtualModifier= Alt;
        action= SetMods(modifiers=modMapMods,clearLocks);
      };
       };
    };`


  tokenizer, err = parse_keymap(transmute([]u8)(content), context.allocator)

  // for interpret in tokenizer.compatibility.interprets {
  //   log.info(interpret)
  // }

  // for indicator in tokenizer.compatibility.indicators {
  //   log.info(indicator)
  // }

  testing.expect(t, err == nil, "AN ERROR OCCOURED")
}

@(test)
types_parse_test :: proc(t: ^testing.T) {
  bytes: []u8
  keymap: Keymap_Context

  err: error.Error
  content := `xkb_keymap {
    xkb_types "(unnamed)" {
      virtual_modifiers NumLock,Alt,LevelThree,Super,LevelFive,Meta,Hyper,ScrollLock;

      type "ONE_LEVEL" {
        modifiers= none;
        level_name[1]= "Any";
      };
      type "TWO_LEVEL" {
        modifiers= Shift;
        map[Shift]= 2;
        level_name[1]= "Base";
        level_name[2]= "Shift";
      };
      type "ALPHABETIC" {
        modifiers= Shift+Lock;
        map[Shift]= 2;
        map[Lock]= 2;
        level_name[1]= "Base";
        level_name[2]= "Caps";
      };
       };
    };`


  _, err = parse_keymap(transmute([]u8)(content), context.allocator)

  testing.expect(t, err == nil, "AN ERROR OCCOURED")
}

package main
ArgumentKind :: enum {
  Int,
  Uint,
  Fixed,
  String,
  Object,
  NewId,
  Array,
  Fd,
}
Request :: struct {
  name: string,
  arguments: []ArgumentKind,
}
Event :: struct {
  name: string,
  arguments: []ArgumentKind,
}
Interface :: struct {
  name: string,
  requests: []Request,
  events: []Event,
}
interfaces := [?]Interface{
  Interface{
    name = "display",
    requests = {
      Request{
        name = "sync",
        args = { .NewId }
      },
      Request{
        name = "get_registry",
        args = { .NewId }
      },
      Request{
        name = "error",
        args = { .Object, .Uint, .String }
      },
      Request{
        name = "delete_id",
        args = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "registry",
    requests = {
      Request{
        name = "bind",
        args = { .Uint, .NewId }
      },
      Request{
        name = "global",
        args = { .Uint, .String, .Uint }
      },
      Request{
        name = "global_remove",
        args = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "callback",
    requests = {
      Request{
        name = "done",
        args = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "compositor",
    requests = {
      Request{
        name = "create_surface",
        args = { .NewId }
      },
      Request{
        name = "create_region",
        args = { .NewId }
      },
    },
    events = {
    },
  },
  Interface{
    name = "shm_pool",
    requests = {
      Request{
        name = "create_buffer",
        args = { .NewId, .Int, .Int, .Int, .Int, .Uint }
      },
      Request{
        name = "destroy",
        args = {  }
      },
      Request{
        name = "resize",
        args = { .Int }
      },
    },
    events = {
    },
  },
  Interface{
    name = "shm",
    requests = {
      Request{
        name = "create_pool",
        args = { .NewId, .Fd, .Int }
      },
      Request{
        name = "format",
        args = { .Uint }
      },
      Request{
        name = "release",
        args = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "buffer",
    requests = {
      Request{
        name = "destroy",
        args = {  }
      },
      Request{
        name = "release",
        args = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "data_offer",
    requests = {
      Request{
        name = "accept",
        args = { .Uint, .String }
      },
      Request{
        name = "receive",
        args = { .String, .Fd }
      },
      Request{
        name = "destroy",
        args = {  }
      },
      Request{
        name = "offer",
        args = { .String }
      },
      Request{
        name = "finish",
        args = {  }
      },
      Request{
        name = "set_actions",
        args = { .Uint, .Uint }
      },
      Request{
        name = "source_actions",
        args = { .Uint }
      },
      Request{
        name = "action",
        args = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "data_source",
    requests = {
      Request{
        name = "offer",
        args = { .String }
      },
      Request{
        name = "destroy",
        args = {  }
      },
      Request{
        name = "target",
        args = { .String }
      },
      Request{
        name = "send",
        args = { .String, .Fd }
      },
      Request{
        name = "cancelled",
        args = {  }
      },
      Request{
        name = "set_actions",
        args = { .Uint }
      },
      Request{
        name = "dnd_drop_performed",
        args = {  }
      },
      Request{
        name = "dnd_finished",
        args = {  }
      },
      Request{
        name = "action",
        args = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "data_device",
    requests = {
      Request{
        name = "start_drag",
        args = { .Object, .Object, .Object, .Uint }
      },
      Request{
        name = "set_selection",
        args = { .Object, .Uint }
      },
      Request{
        name = "data_offer",
        args = { .NewId }
      },
      Request{
        name = "enter",
        args = { .Uint, .Object, .Fixed, .Fixed, .Object }
      },
      Request{
        name = "leave",
        args = {  }
      },
      Request{
        name = "motion",
        args = { .Uint, .Fixed, .Fixed }
      },
      Request{
        name = "drop",
        args = {  }
      },
      Request{
        name = "selection",
        args = { .Object }
      },
      Request{
        name = "release",
        args = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "data_device_manager",
    requests = {
      Request{
        name = "create_data_source",
        args = { .NewId }
      },
      Request{
        name = "get_data_device",
        args = { .NewId, .Object }
      },
    },
    events = {
    },
  },
  Interface{
    name = "shell",
    requests = {
      Request{
        name = "get_shell_surface",
        args = { .NewId, .Object }
      },
    },
    events = {
    },
  },
  Interface{
    name = "shell_surface",
    requests = {
      Request{
        name = "pong",
        args = { .Uint }
      },
      Request{
        name = "move",
        args = { .Object, .Uint }
      },
      Request{
        name = "resize",
        args = { .Object, .Uint, .Uint }
      },
      Request{
        name = "set_toplevel",
        args = {  }
      },
      Request{
        name = "set_transient",
        args = { .Object, .Int, .Int, .Uint }
      },
      Request{
        name = "set_fullscreen",
        args = { .Uint, .Uint, .Object }
      },
      Request{
        name = "set_popup",
        args = { .Object, .Uint, .Object, .Int, .Int, .Uint }
      },
      Request{
        name = "set_maximized",
        args = { .Object }
      },
      Request{
        name = "set_title",
        args = { .String }
      },
      Request{
        name = "set_class",
        args = { .String }
      },
      Request{
        name = "ping",
        args = { .Uint }
      },
      Request{
        name = "configure",
        args = { .Uint, .Int, .Int }
      },
      Request{
        name = "popup_done",
        args = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "surface",
    requests = {
      Request{
        name = "destroy",
        args = {  }
      },
      Request{
        name = "attach",
        args = { .Object, .Int, .Int }
      },
      Request{
        name = "damage",
        args = { .Int, .Int, .Int, .Int }
      },
      Request{
        name = "frame",
        args = { .NewId }
      },
      Request{
        name = "set_opaque_region",
        args = { .Object }
      },
      Request{
        name = "set_input_region",
        args = { .Object }
      },
      Request{
        name = "commit",
        args = {  }
      },
      Request{
        name = "enter",
        args = { .Object }
      },
      Request{
        name = "leave",
        args = { .Object }
      },
      Request{
        name = "set_buffer_transform",
        args = { .Int }
      },
      Request{
        name = "set_buffer_scale",
        args = { .Int }
      },
      Request{
        name = "damage_buffer",
        args = { .Int, .Int, .Int, .Int }
      },
      Request{
        name = "offset",
        args = { .Int, .Int }
      },
      Request{
        name = "preferred_buffer_scale",
        args = { .Int }
      },
      Request{
        name = "preferred_buffer_transform",
        args = { .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "seat",
    requests = {
      Request{
        name = "capabilities",
        args = { .Uint }
      },
      Request{
        name = "get_pointer",
        args = { .NewId }
      },
      Request{
        name = "get_keyboard",
        args = { .NewId }
      },
      Request{
        name = "get_touch",
        args = { .NewId }
      },
      Request{
        name = "name",
        args = { .String }
      },
      Request{
        name = "release",
        args = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "pointer",
    requests = {
      Request{
        name = "set_cursor",
        args = { .Uint, .Object, .Int, .Int }
      },
      Request{
        name = "enter",
        args = { .Uint, .Object, .Fixed, .Fixed }
      },
      Request{
        name = "leave",
        args = { .Uint, .Object }
      },
      Request{
        name = "motion",
        args = { .Uint, .Fixed, .Fixed }
      },
      Request{
        name = "button",
        args = { .Uint, .Uint, .Uint, .Uint }
      },
      Request{
        name = "axis",
        args = { .Uint, .Uint, .Fixed }
      },
      Request{
        name = "release",
        args = {  }
      },
      Request{
        name = "frame",
        args = {  }
      },
      Request{
        name = "axis_source",
        args = { .Uint }
      },
      Request{
        name = "axis_stop",
        args = { .Uint, .Uint }
      },
      Request{
        name = "axis_discrete",
        args = { .Uint, .Int }
      },
      Request{
        name = "axis_value120",
        args = { .Uint, .Int }
      },
      Request{
        name = "axis_relative_direction",
        args = { .Uint, .Uint }
      },
    },
    events = {
    },
  },
  Interface{
    name = "keyboard",
    requests = {
      Request{
        name = "keymap",
        args = { .Uint, .Fd, .Uint }
      },
      Request{
        name = "enter",
        args = { .Uint, .Object, .Array }
      },
      Request{
        name = "leave",
        args = { .Uint, .Object }
      },
      Request{
        name = "key",
        args = { .Uint, .Uint, .Uint, .Uint }
      },
      Request{
        name = "modifiers",
        args = { .Uint, .Uint, .Uint, .Uint, .Uint }
      },
      Request{
        name = "release",
        args = {  }
      },
      Request{
        name = "repeat_info",
        args = { .Int, .Int }
      },
    },
    events = {
    },
  },
  Interface{
    name = "touch",
    requests = {
      Request{
        name = "down",
        args = { .Uint, .Uint, .Object, .Int, .Fixed, .Fixed }
      },
      Request{
        name = "up",
        args = { .Uint, .Uint, .Int }
      },
      Request{
        name = "motion",
        args = { .Uint, .Int, .Fixed, .Fixed }
      },
      Request{
        name = "frame",
        args = {  }
      },
      Request{
        name = "cancel",
        args = {  }
      },
      Request{
        name = "release",
        args = {  }
      },
      Request{
        name = "shape",
        args = { .Int, .Fixed, .Fixed }
      },
      Request{
        name = "orientation",
        args = { .Int, .Fixed }
      },
    },
    events = {
    },
  },
  Interface{
    name = "output",
    requests = {
      Request{
        name = "geometry",
        args = { .Int, .Int, .Int, .Int, .Int, .String, .String, .Int }
      },
      Request{
        name = "mode",
        args = { .Uint, .Int, .Int, .Int }
      },
      Request{
        name = "done",
        args = {  }
      },
      Request{
        name = "scale",
        args = { .Int }
      },
      Request{
        name = "release",
        args = {  }
      },
      Request{
        name = "name",
        args = { .String }
      },
      Request{
        name = "description",
        args = { .String }
      },
    },
    events = {
    },
  },
  Interface{
    name = "region",
    requests = {
      Request{
        name = "destroy",
        args = {  }
      },
      Request{
        name = "add",
        args = { .Int, .Int, .Int, .Int }
      },
      Request{
        name = "subtract",
        args = { .Int, .Int, .Int, .Int }
      },
    },
    events = {
    },
  },
  Interface{
    name = "subcompositor",
    requests = {
      Request{
        name = "destroy",
        args = {  }
      },
      Request{
        name = "get_subsurface",
        args = { .NewId, .Object, .Object }
      },
    },
    events = {
    },
  },
  Interface{
    name = "subsurface",
    requests = {
      Request{
        name = "destroy",
        args = {  }
      },
      Request{
        name = "set_position",
        args = { .Int, .Int }
      },
      Request{
        name = "place_above",
        args = { .Object }
      },
      Request{
        name = "place_below",
        args = { .Object }
      },
      Request{
        name = "set_sync",
        args = {  }
      },
      Request{
        name = "set_desync",
        args = {  }
      },
    },
    events = {
    },
  },
  Interface{
    name = "fixes",
    requests = {
      Request{
        name = "destroy",
        args = {  }
      },
      Request{
        name = "destroy_registry",
        args = { .Object }
      },
    },
    events = {
    },
  },
}

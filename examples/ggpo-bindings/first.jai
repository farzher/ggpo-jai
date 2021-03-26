// todo: this example sucks

window_width :: 800;
window_height :: 600;

main :: () {
  init_ggpo();

  // create window
  window = create_window(window_name="GGPO in JAI", width=window_width, height=window_height);
  simp.simp_init(window, window_width, window_height, render_width, render_height, windowed=true, vsync=false);

  // load textures
  textures.ship = make_texture("data/ship.png");

  // game loop
  // todo: this vectorwars game loop sucks. but why?
  next := getms();
  while !stopgameloop {

    now := getms();
    ggpo_idle(ggpo, xx max(cast(float64)0, next-now-1));
    if(now >= next) {
      next += cast(float)1000/60;

      if inputs() then update();
      render();

      for p, i: players {
        if p.type == .GGPO_PLAYERTYPE_LOCAL continue;
        stats: GGPONetworkStats;
        ggpo_get_network_stats(ggpo, handles[i], *stats);
        log("stats", i, stats);
      }

      reset_temporary_storage();
    }
  }
}




















inputs :: () -> bool {
  update_window_events();

  if skipframes > 0 {
    log("skipframes", skipframes);
    skipframes -= 1;
    return false;
  }

  for event : events_this_frame {
    if event.type == .QUIT || event.key_code == .ESCAPE stopgameloop = true;

    if event.type == .KEYBOARD {
      key := event.key_code;

      if key == xx #char "W" || key == .ARROW_UP        input.up = xx event.key_pressed;
      if key == xx #char "A" || key == .ARROW_LEFT      input.left = xx event.key_pressed;
      if key == xx #char "S" || key == .ARROW_DOWN      input.down = xx event.key_pressed;
      if key == xx #char "D" || key == .ARROW_RIGHT     input.right = xx event.key_pressed;
    }
  }

  if .GGPO_OK == ggpo_add_local_input(ggpo, handles[localplayerindex], *input, size_of(Input)) {
    if .GGPO_OK == ggpo_synchronize_input(ggpo, *inputvalues, size_of(type_of(inputvalues)), *disconnect_flags) {
      return true;
    }
  }
  return false;
}

update :: () {
  for input, i: inputvalues {
    if input.up    gs.players[i].y += .02;
    if input.down  gs.players[i].y -= .02;
    if input.left  gs.players[i].x -= .02;
    if input.right gs.players[i].x += .02;
  }

  ggpo_advance_frame(ggpo);
}

render :: () {
  for player: gs.players
    render_sprite_quad_centered(*textures.ship, player.xy, .{.2, .2}, .{1,1,1,1});

  simp.swap_buffers(window);

  // clear screen
  simp.update_window(window, window_width, window_height, render_width, render_height); // idk what this does
  simp.clear_render_target(.2, .3, .3, 1);
}



















init_ggpo :: () {
  ggpo_init_winsock();

  cmdargs := get_command_line_arguments();
  log("cmdargs", cmdargs);

  if cmdargs.count != 5 {
    log("+-----------------------------------------+");
    log("| invalid command line arguments          |");
    log("| checkout run2p.bat                      |");
    log("| example:                                |");
    log("| first.exe 7000 2 local 127.0.0.1:7001   |");
    log("| first.exe 7001 2 127.0.0.1:7000 local   |");
    log("+-----------------------------------------+");
    stopgameloop = true;
    return;
  }

  cb.begin_game      = (gamename: cstring) -> bool #c_call { new_context: Context; push_context new_context {
    log("begin_game", fromcstr(gamename));
    return true;
  } };
  cb.save_game_state = (buffer: * *u8, len: *s32, checksum: *s32, frame: s32) -> bool #c_call { new_context: Context; push_context new_context {
    <<buffer = alloc(size_of(GS));
    <<len = size_of(GS);
    memcpy(<<buffer, *gs, size_of(GS));
    // log("save_game_state", buffer, <<buffer);
    // <<checksum = 1;
    return true;
  } };
  cb.load_game_state = (buffer: *u8, len: s32) -> bool #c_call { new_context: Context; push_context new_context {
    memcpy(*gs, buffer, len);
    // log("load_game_state", buffer, len);
    return true;
  } };
  cb.log_game_state  = (filename: cstring, buffer: *u8, len: s32) -> bool #c_call { new_context: Context; push_context new_context {
    log("log_game_state");
    return true;
  } };
  cb.free_buffers    = (buffer: *void) -> void #c_call { new_context: Context; push_context new_context {
    free(buffer);
    // log("free_buffer");
  } };
  cb.advance_frame   = (flags: s32) -> bool #c_call { new_context: Context; push_context new_context {
    ggpo_synchronize_input(ggpo, *inputvalues, size_of(type_of(inputvalues)), *disconnect_flags);
    update();
    // log("advance_frame");
    return true;
  } };
  cb.on_event        = (event: *GGPOEvent) -> bool #c_call { new_context: Context; push_context new_context {
    log("on_event", event.code);
    if event.code == {
      case .GGPO_EVENTCODE_TIMESYNC;
        skipframes += event.timesync.frames_ahead;
        // Sleep(1000 * event.timesync.frames_ahead / 60);
    }
    return true;
  } };




  localport: u16 = xx to_integer(cmdargs[1]);
  // playercount: u8 = xx to_integer(cmdargs[2]);
  ggpo_start_session(*ggpo, *cb, "GGPO in JAI", num_players=GGPO_PLAYERCOUNT, input_size=size_of(Input), localport=localport);
  // ggpo_start_synctest(*ggpo, *cb, "GGPO in JAI", num_players=GGPO_PLAYERCOUNT, input_size=size_of(Input), 1);
  ggpo_set_disconnect_timeout(ggpo, 3000);
  ggpo_set_disconnect_notify_start(ggpo, 1000);

  for * player, i: players {
    playerinfoarg := cmdargs[3+i];
    player.size = size_of(GGPOPlayer);
    player.player_num = cast(s32) i+1;
    if playerinfoarg == "local" {
      player.type = .GGPO_PLAYERTYPE_LOCAL;
      localplayerindex = i;
    } else {
      player.type = .GGPO_PLAYERTYPE_REMOTE;
      ipport := String.split(playerinfoarg, ":");
      ip := ipport[0];
      memcpy(player.remote.ip_address.data, ip.data, ip.count);
      player.remote.port = xx to_integer(ipport[1]);
    }
    log("player", <<player);
    log("ggpo_add_player", ggpo_add_player(ggpo, player, *handles[i]));
    if player.type == .GGPO_PLAYERTYPE_LOCAL ggpo_set_frame_delay(ggpo, handles[i], 0);
  }
}


















#import "Basic";
log :: (args:..Any) { for args print("% ", it); print("\n"); }

String :: #import "String";
#import "Math";
#import "Input";
#import "Window_Creation";
#import "Windows";
simp :: #import "Simp";
Texture :: simp.Texture;

#import "GGPO";
// #load "ggpo.jai";
// #load "winsock.jai";

render_width :: window_width;
render_height :: window_height;

GS :: struct {players: [2]Player; }
Player :: struct {using xy: Vector2; }
Input :: struct {up:bool; down:bool; left:bool; right:bool; }

gs:GS;
input:Input;

ggpo: *GGPOSession;
cb: GGPOSessionCallbacks;
inputvalues: [GGPO_PLAYERCOUNT]Input;
disconnect_flags: s32;
localplayerindex: int;
GGPO_PLAYERCOUNT :: 2;
handles: [GGPO_PLAYERCOUNT]GGPOPlayerHandle;
players: [GGPO_PLAYERCOUNT]GGPOPlayer;

window: HWND;
stopgameloop: bool;
skipframes: int;
textures: struct {ship: Texture; };









make_texture :: (filename: string) -> Texture, bool {
  result: Texture;
  success := simp.load_texture_from_file(*result, filename);
  return result, success;
}
render_sprite_quad_centered :: (texture: *Texture, _pos: Vector2, size: Vector2, color: Vector4) {
  simp.set_shader_for_images(texture);
  pos := _pos * Vector2.{window_width, window_height};
  h := make_vector2(size.x*.5*window_width, 0);
  v := make_vector2(0, size.y*.5*window_height);
  simp.immediate_quad(pos-h-v, pos+h-v, pos+h+v, pos-h+v, color);
}

cstring :: *u8;
fromcstr :: (cstr: cstring) -> string {
  ret: string;
  if (cstr == null) return ret;
  ret.data = xx cstr;
  ret.count = c_style_strlen(xx cstr);
  return ret;
}

getms :: () -> float64 {
  return cast(float64)(get_time()*1000);
}

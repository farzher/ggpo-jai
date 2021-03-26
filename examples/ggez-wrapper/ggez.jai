ggez_init :: (gamestateptr: *$GameState, inputptr: *$Input, updatefn: ()->(), localport:u16, playerinfo: []string, fps:u16=60) {
  // start_timestamp = getms(); // TODO: need to make sure this is syncronized

  ggpo_init_winsock();

  _GameState = GameState;
  _Input = Input;
  _gamestateptr = xx gamestateptr;
  _inputptr = xx inputptr;
  sizeofgamestate = size_of(GameState);
  sizeofinput = size_of(Input);
  _updatefn = updatefn;
  _fps = fps;
  _msperframe = cast(float64)1000/fps;




  cb.begin_game      = (gamename: cstring) -> bool #c_call { return true; };
  cb.save_game_state = (buffer: * *u8, len: *s32, checksum: *s32, frame: s32) -> bool #c_call { new_context: Context; push_context new_context {
    <<len = size_of(type_of(currentframe)) + sizeofgamestate;
    <<buffer = alloc(<<len);
    memcpy(<<buffer, *currentframe, size_of(type_of(currentframe)));
    memcpy(<<buffer + size_of(type_of(currentframe)), _gamestateptr, sizeofgamestate);
    return true;
  }};
  cb.load_game_state = (buffer: *u8, len: s32) -> bool #c_call { new_context: Context; push_context new_context {
    memcpy(*currentframe, buffer, size_of(type_of(currentframe)));
    memcpy(_gamestateptr, buffer + size_of(type_of(currentframe)), sizeofgamestate);
    return true;
  }};
  cb.log_game_state  = (filename: cstring, buffer: *u8, len: s32) -> bool #c_call { new_context: Context; push_context new_context {
    return true;
  }};
  cb.free_buffers    = (buffer: *void) -> void #c_call { new_context: Context; push_context new_context {
    free(buffer);
  }};
  cb.advance_frame   = (flags: s32) -> bool #c_call { new_context: Context; push_context new_context {
    ggpo_synchronize_input(ggpo, *inputvalues, size_of(type_of(inputvalues)), *disconnect_flags);
    update_gs();
    return true;
  }};
  cb.on_event        = (event: *GGPOEvent) -> bool #c_call { new_context: Context; push_context new_context {
    log(<<event);

    if event.code == {
      // case .GGPO_EVENTCODE_CONNECTED_TO_PEER;
      // case .GGPO_EVENTCODE_SYNCHRONIZED_WITH_PEER;
      // case .GGPO_EVENTCODE_RUNNING;
      //   start_timestamp = getms();
      //   log("start", start_timestamp);

      case .GGPO_EVENTCODE_TIMESYNC;
        // skipframes += event.timesync.frames_ahead;
        start_timestamp += event.timesync.frames_ahead * _msperframe;
    }
    return true;
  }};





  ggpo_start_session(*ggpo, *cb, "ggez", num_players=GGPO_PLAYERCOUNT, input_size=sizeofinput, localport=localport);
  ggpo_set_disconnect_timeout(ggpo, 3000);
  ggpo_set_disconnect_notify_start(ggpo, 1000);

  for * player, i: players {
    playerinfoarg := playerinfo[i];
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

    ggpo_add_player(ggpo, player, *handles[i]);
    if player.type == .GGPO_PLAYERTYPE_LOCAL ggpo_set_frame_delay(ggpo, handles[i], 0);
  }
}


ggez_idle :: () {
  ggpo_idle(ggpo, 0);
}
ggez_update :: () #expand {
  `defer ggez_idle();
  // if skipframes > 0 {
  //   skipframes -= 1;
  //   return;
  // }

  if start_timestamp + currentframe*_msperframe < getms() {
    if .GGPO_OK == ggpo_add_local_input(ggpo, handles[localplayerindex], _inputptr, sizeofinput) {
      if .GGPO_OK == ggpo_synchronize_input(ggpo, *inputvalues, size_of(type_of(inputvalues)), *disconnect_flags) {
        update_gs();
      }
    }
  }
}
ggez_inputs :: () -> type_of(inputvalues) {return inputvalues; }
update_gs :: () {
  currentframe += 1;
  log("currentframe", currentframe);
  _updatefn();
  ggpo_advance_frame(ggpo);
}






#import "ggpo";
String :: #import "String";

ggpo: *GGPOSession;
cb: GGPOSessionCallbacks;
disconnect_flags: s32;
localplayerindex: int;
GGPO_PLAYERCOUNT :: 2;
inputvalues: [GGPO_PLAYERCOUNT]Input;
handles: [GGPO_PLAYERCOUNT]GGPOPlayerHandle;
players: [GGPO_PLAYERCOUNT]GGPOPlayer;

skipframes: int;
start_timestamp: float64;

_GameState: Type;
_Input: Type;
_gamestateptr: *void;//*GameState;
_inputptr: *void;//*Input
sizeofgamestate: s32;
sizeofinput: s32;
_updatefn: ()->();
_fps:u16;
_msperframe:float64;
currentframe: u32;









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


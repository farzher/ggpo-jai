// example of using GGPO in jai
// usage: run2p.bat

window_width :: 800;
window_height :: 600;

main :: () {
  init_ggez();

  // create window
  window = create_window(window_name="GGPO in JAI", width=window_width, height=window_height);
  simp.simp_init(window, window_width, window_height, render_width, render_height, windowed=true, vsync=true);

  // load textures
  textures.ship = make_texture("data/ship.png");

  // init gamestate
  for * p: gs.players  p.xy = .{.5, .5};

  // game loop
  while !stopgameloop {
    ggez_idle();
    inputs();
    ggez_update();
    render();
  }
}














inputs :: () {
  update_window_events();

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
}

update :: () {
  for input, i: ggez_inputs() {
    if input.up    gs.players[i].y += .02;
    if input.down  gs.players[i].y -= .02;
    if input.left  gs.players[i].x -= .02;
    if input.right gs.players[i].x += .02;
  }
}

render :: () {
  for player: gs.players
    render_sprite_quad_centered(*textures.ship, player.xy, .{.2, .2}, .{1,1,1,1});

  simp.swap_buffers(window);

  // clear screen
  simp.update_window(window, window_width, window_height, render_width, render_height); // idk what this does
  simp.clear_render_target(.2, .3, .3, 1);
}

















init_ggez :: () {
  cmdargs := get_command_line_arguments();
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
  localport: u16 = xx to_integer(cmdargs[1]);
  playerinfo: []string;
  playerinfo.data = cmdargs.data + 3;
  playerinfo.count = 2;

  ggez_init(gamestateptr=*gs, inputptr=*input, updatefn=update, localport=localport, playerinfo=playerinfo, fps=60);
}

























#import "Basic";
log :: (args:..Any) { for args print("% ", it); print("\n"); }

#import "Math";
#import "Input";
#import "Window_Creation";
#import "Windows";
simp :: #import "Simp";
Texture :: simp.Texture;

#load "ggez.jai";

render_width :: window_width;
render_height :: window_height;

GameState :: struct {players: [2]Player; }
Player :: struct {using xy: Vector2; }
Input :: struct {up:bool; down:bool; left:bool; right:bool; }

gs:GameState;
input:Input;

window: HWND;
stopgameloop: bool;
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

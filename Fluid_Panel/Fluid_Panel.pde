/**
 * 
 * PixelFlow | Copyright (C) 2016 Thomas Diewald - http://thomasdiewald.com
 * 
 * A Processing/Java library for high performance GPU-Computing (GLSL).
 * MIT License: https://opensource.org/licenses/MIT
 * 
 */




import com.thomasdiewald.pixelflow.java.DwPixelFlow;
import com.thomasdiewald.pixelflow.java.dwgl.DwGLTexture;
import com.thomasdiewald.pixelflow.java.fluid.DwFluid2D;
import com.thomasdiewald.pixelflow.java.fluid.DwFluidParticleSystem2D;
import com.thomasdiewald.pixelflow.java.imageprocessing.filter.DwFilter;

import controlP5.Accordion;
import controlP5.ControlP5;
import controlP5.Group;
import controlP5.RadioButton;
import controlP5.Toggle;
import processing.core.*;
import processing.opengl.PGraphics2D;

import spout.*;
PImage img; // Image to receive a texture
Spout sender;
Spout receiver;



// This example shows a very basic fluid simulation setup. 
// Multiple emitters add velocity/temperature/density each iteration.
// Obstacles are added at startup, by just drawing into a usual PGraphics object.
// The same way, obstacles can be added/removed dynamically.
//
// additionally some locations add temperature to the scene, to show how
// buoyancy works.
//
//
// controls:
//
// LMB: add Density + Velocity
// MMB: draw obstacles
// RMB: clear obstacles

private class MyFluidData implements DwFluid2D.FluidData {

  // update() is called during the fluid-simulation update step.
  @Override
    public void update(DwFluid2D fluid) {

    float px, py, vx, vy, radius, vscale, r, g, b, intensity, temperature;

    //// add impulse: density + temperature - red
    float animator = sin(fluid.simulation_step*0.1f);

    //intensity = 1.0f;
    //px = 2*width/3f;
    //py = 150;
    //radius = 50;
    //r = 1.0f;
    //g = 0.0f;
    //b = 0.3f;
    //fluid.addDensity(px, py, radius, r, g, b, intensity);

    //temperature = animator * 20f;
    //fluid.addTemperature(px, py, radius, temperature);

    // add impulse: density - black
    if (keyz[0]) {
      px = width/2f;
      py = height;
      radius = 50.0f;
      r = g = b = 0.0f;
      intensity = 1.0f;
      fluid.addDensity(px, py, radius, r, g, b, intensity, 3);
      vx=(animator+0.5)*90;
      vy=-100f;
      fluid.addVelocity(px, py, radius, vx, vy);
    }

    // add impulse: density - red
    if (keyz[3]) {
      px = width;
      py = height/2;
      radius = 50.0f;
      r = 1.0f;
      g = 0.0f;
      b = 0.0f;
      intensity = 2.0f;
      fluid.addDensity(px, py, radius, r, g, b, intensity, 3);
      vx=-100f;
      vy=(animator+0.2)*90;
      fluid.addVelocity(px, py, radius, vx, vy);
    }

    // add impulse: density - green
    if (keyz[2]) {
      px = width/2f;
      py = 0.0f;
      radius = 50.0f;
      r = 0.0f;
      g = 1.0f;
      b = 0.0f;
      intensity = 1.0f;
      fluid.addDensity(px, py, radius, r, g, b, intensity, 3);
      vx=(animator+0.1)*90;
      vy=100f;
      fluid.addVelocity(px, py, radius, vx, vy);
    }

    // add impulse: density - blue
    if (keyz[1]) {
      px = 0.0f;
      py = height/2;
      radius = 50.0f;
      r = 0.0f;
      g = 0.0f;
      b = 1.0f;
      intensity = 1.0f;
      fluid.addDensity(px, py, radius, r, g, b, intensity, 3);
      vx=100f;
      vy=(animator+0.0)*90;
      fluid.addVelocity(px, py, radius, vx, vy);
    }

    boolean mouse_input = !cp5.isMouseOver() && mousePressed && !obstacle_painter.isDrawing();

    // add impulse: density + velocity
    if (mouse_input && mouseButton == LEFT) {
      radius = 15;
      vscale = 15;
      px     = mouseX;
      py     = height-mouseY;
      vx     = (mouseX - pmouseX) * +vscale;
      vy     = (mouseY - pmouseY) * -vscale;

      //fluid.addDensity(px, py, radius, 0.75f, 0.75f, 0.75f, 1.0f);
      fluid.addVelocity(px, py, radius, vx, vy);
    }

    // ADD DENSITY FROM TEXTURE:
    // pg_image              ... contains our current density input
    // fluid.tex_density.dst ... density render target
    // fluid.tex_density.src ... density from previous fluid update step

    // mix value
    float mix = (fluid.simulation_step == 0) ? 1.0f : 0.01f;

    // copy pg_density_input to temporary fluid texture
    DwFilter.get(context).copy.apply(pg_density_input, fluid.tex_density.dst);

    // mix both textures
    DwGLTexture[] tex = {fluid.tex_density.src, fluid.tex_density.dst};
    float[]       mad = {1f-mix, 0f, mix, 0f};
    DwFilter.get(context).merge.apply(fluid.tex_density.dst, tex, mad);

    // swap, dst becomes src, src is used as input for the next fluid update step
    fluid.tex_density.swap();
  }
}


int viewport_w = 1080;
int viewport_h = 1080;
int fluidgrid_scale = 1;

int gui_w = 200;
int gui_x = 20;
int gui_y = 20;

DwPixelFlow context;

DwFluid2D fluid;

ObstaclePainter obstacle_painter;

// render targets
PGraphics2D pg_fluid;         // primary fluid render target
PGraphics2D pg_density_input; // texture buffer for adding density

//texture-buffer, for adding obstacles
PGraphics2D pg_obstacles;

// some state variables for the GUI/display
int     BACKGROUND_COLOR           = 0;
boolean UPDATE_FLUID               = true;
boolean DISPLAY_FLUID_TEXTURES     = true;
boolean DISPLAY_FLUID_VECTORS      = false;
int     DISPLAY_fluid_texture_mode = 0;

public void settings() {
  size(viewport_w, viewport_h, P2D);
  smooth(2);
}
boolean keyz[] = new boolean [4];

public void setup() {

  // main library context
  context = new DwPixelFlow(this);
  context.print();
  context.printGL();

  // fluid simulation
  fluid = new DwFluid2D(context, viewport_w, viewport_h, fluidgrid_scale);

  // set some simulation parameters
  fluid.param.dissipation_density     = 1.0f;
  fluid.param.dissipation_velocity    = 1.0f;
  fluid.param.dissipation_temperature = 1.0f;
  fluid.param.vorticity               = 1.0f;
  fluid.param.num_jacobi_projection   = 80;
  fluid.param.timestep                = 1.0f;
  fluid.param.gridscale               = 1.00f;

  // interface for adding data to the fluid simulation
  MyFluidData cb_fluid_data = new MyFluidData();
  fluid.addCallback_FluiData(cb_fluid_data);

  // pgraphics for fluid
  pg_fluid = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
  pg_fluid.smooth(4);
  pg_fluid.beginDraw();
  pg_fluid.background(BACKGROUND_COLOR);
  pg_fluid.endDraw();


  // image/buffer that will be used as density input
  pg_density_input = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
  pg_density_input.smooth(0);
  pg_density_input.beginDraw();
  pg_density_input.clear();
  pg_density_input.endDraw();

  // pgraphics for obstacles
  pg_obstacles = (PGraphics2D) createGraphics(viewport_w, viewport_h, P2D);
  pg_obstacles.smooth(0);
  pg_obstacles.beginDraw();
  pg_obstacles.clear();

  // border-obstacle
  pg_obstacles.strokeWeight(20);
  pg_obstacles.stroke(64);
  pg_obstacles.noFill();
  pg_obstacles.rect(0, 0, pg_obstacles.width, pg_obstacles.height);
  pg_obstacles.endDraw();

  // class, that manages interactive drawing (adding/removing) of obstacles
  obstacle_painter = new ObstaclePainter(pg_obstacles);

  createGUI();

  // spout
  receiver = new Spout(this);
  receiver.createReceiver("FluidRSIn");
  img = createImage(width, height, ARGB);
  sender = new Spout(this);
  sender.createSender("FluidRSOut");
  frameRate(60);
}



public void draw() {    
  receiver.receiveTexture(pg_density_input);

  // update simulation
  if (UPDATE_FLUID) {
    fluid.addObstacles(pg_obstacles);
    fluid.update();
  }

  // clear render target
  pg_fluid.beginDraw();
  pg_fluid.background(BACKGROUND_COLOR);
  pg_fluid.endDraw();


  // render fluid stuff
  if (DISPLAY_FLUID_TEXTURES) {
    // render: density (0), temperature (1), pressure (2), velocity (3)
    fluid.renderFluidTextures(pg_fluid, DISPLAY_fluid_texture_mode);
  }

  if (DISPLAY_FLUID_VECTORS) {
    // render: velocity vector field
    fluid.renderFluidVectors(pg_fluid, 10);
  }


  // display
  image(pg_fluid, 0, 0);
  image(pg_obstacles, 0, 0);

  obstacle_painter.displayBrush(this.g);

  // info
  String txt_fps = String.format(getClass().getName()+ "   [size %d/%d]   [frame %d]   [fps %6.2f]", fluid.fluid_w, fluid.fluid_h, fluid.simulation_step, frameRate);
  surface.setTitle(txt_fps);

  sender.sendTexture();
}



public void mousePressed() {
  if (mouseButton == CENTER ) obstacle_painter.beginDraw(1); // add obstacles
  if (mouseButton == RIGHT  ) obstacle_painter.beginDraw(2); // remove obstacles
}

public void mouseDragged() {
  obstacle_painter.draw();
}

public void mouseReleased() {
  obstacle_painter.endDraw();
}


public void fluid_resizeUp() {
  fluid.resize(width, height, fluidgrid_scale = max(1, --fluidgrid_scale));
}
public void fluid_resizeDown() {
  fluid.resize(width, height, ++fluidgrid_scale);
}
public void fluid_reset() {
  fluid.reset();
}
public void fluid_togglePause() {
  UPDATE_FLUID = !UPDATE_FLUID;
}
public void fluid_displayMode(int val) {
  DISPLAY_fluid_texture_mode = val;
  DISPLAY_FLUID_TEXTURES = DISPLAY_fluid_texture_mode != -1;
}
public void fluid_displayVelocityVectors(int val) {
  DISPLAY_FLUID_VECTORS = val != -1;
}

void keyPressed() {
  if (key == 'i')  keyz[0] = true;
  if (key == 'j')  keyz[1] = true;
  if (key == 'k')  keyz[2] = true;
  if (key == 'l')  keyz[3] = true;
}

public void keyReleased() {
  if (key == 'p') fluid_togglePause(); // pause / unpause simulation
  if (key == '+') fluid_resizeUp();    // increase fluid-grid resolution
  if (key == '-') fluid_resizeDown();  // decrease fluid-grid resolution
  if (key == 'r') fluid_reset();       // restart simulation

  if (key == '1') DISPLAY_fluid_texture_mode = 0; // density
  if (key == '2') DISPLAY_fluid_texture_mode = 1; // temperature
  if (key == '3') DISPLAY_fluid_texture_mode = 2; // pressure
  if (key == '4') DISPLAY_fluid_texture_mode = 3; // velocity

  if (key == 'q') DISPLAY_FLUID_TEXTURES = !DISPLAY_FLUID_TEXTURES;
  if (key == 'w') DISPLAY_FLUID_VECTORS  = !DISPLAY_FLUID_VECTORS;

  if (key == 'i')  keyz[0] = false;
  if (key == 'j')  keyz[1] = false;
  if (key == 'k')  keyz[2] = false;
  if (key == 'l')  keyz[3] = false;

  if (key == 's') receiver.selectSender();
}

ControlP5 cp5;

public void createGUI() {
  cp5 = new ControlP5(this);

  int sx, sy, px, py, oy;

  sx = 100; 
  sy = 14; 
  oy = (int)(sy*1.5f);


  ////////////////////////////////////////////////////////////////////////////
  // GUI - FLUID
  ////////////////////////////////////////////////////////////////////////////
  Group group_fluid = cp5.addGroup("fluid");
  {
    group_fluid.setHeight(20).setSize(gui_w, 300)
      .setBackgroundColor(color(16, 180)).setColorBackground(color(16, 180));
    group_fluid.getCaptionLabel().align(CENTER, CENTER);

    px = 10; 
    py = 15;

    cp5.addButton("reset").setGroup(group_fluid).plugTo(this, "fluid_reset"     ).setSize(80, 18).setPosition(px, py);
    cp5.addButton("+"    ).setGroup(group_fluid).plugTo(this, "fluid_resizeUp"  ).setSize(39, 18).setPosition(px+=82, py);
    cp5.addButton("-"    ).setGroup(group_fluid).plugTo(this, "fluid_resizeDown").setSize(39, 18).setPosition(px+=41, py);

    px = 10;

    cp5.addSlider("velocity").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=(int)(oy*1.5f))
      .setRange(0, 1).setValue(fluid.param.dissipation_velocity).plugTo(fluid.param, "dissipation_velocity");

    cp5.addSlider("density").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
      .setRange(0, 1).setValue(fluid.param.dissipation_density).plugTo(fluid.param, "dissipation_density");

    cp5.addSlider("temperature").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
      .setRange(0, 1).setValue(fluid.param.dissipation_temperature).plugTo(fluid.param, "dissipation_temperature");

    cp5.addSlider("vorticity").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
      .setRange(0, 1).setValue(fluid.param.vorticity).plugTo(fluid.param, "vorticity");

    cp5.addSlider("iterations").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
      .setRange(0, 80).setValue(fluid.param.num_jacobi_projection).plugTo(fluid.param, "num_jacobi_projection");

    cp5.addSlider("timestep").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
      .setRange(0, 1).setValue(fluid.param.timestep).plugTo(fluid.param, "timestep");

    cp5.addSlider("gridscale").setGroup(group_fluid).setSize(sx, sy).setPosition(px, py+=oy)
      .setRange(0, 50).setValue(fluid.param.gridscale).plugTo(fluid.param, "gridscale");

    RadioButton rb_setFluid_DisplayMode = cp5.addRadio("fluid_displayMode").setGroup(group_fluid).setSize(80, 18).setPosition(px, py+=(int)(oy*1.5f))
      .setSpacingColumn(2).setSpacingRow(2).setItemsPerRow(2)
      .addItem("Density", 0)
      .addItem("Temperature", 1)
      .addItem("Pressure", 2)
      .addItem("Velocity", 3)
      .activate(DISPLAY_fluid_texture_mode);
    for (Toggle toggle : rb_setFluid_DisplayMode.getItems()) toggle.getCaptionLabel().alignX(CENTER);

    cp5.addRadio("fluid_displayVelocityVectors").setGroup(group_fluid).setSize(18, 18).setPosition(px, py+=(int)(oy*2.5f))
      .setSpacingColumn(2).setSpacingRow(2).setItemsPerRow(1)
      .addItem("Velocity Vectors", 0)
      .activate(DISPLAY_FLUID_VECTORS ? 0 : 2);
  }


  ////////////////////////////////////////////////////////////////////////////
  // GUI - DISPLAY
  ////////////////////////////////////////////////////////////////////////////
  Group group_display = cp5.addGroup("display");
  {
    group_display.setHeight(20).setSize(gui_w, 50)
      .setBackgroundColor(color(16, 180)).setColorBackground(color(16, 180));
    group_display.getCaptionLabel().align(CENTER, CENTER);

    px = 10; 
    py = 15;

    cp5.addSlider("BACKGROUND").setGroup(group_display).setSize(sx, sy).setPosition(px, py)
      .setRange(0, 255).setValue(BACKGROUND_COLOR).plugTo(this, "BACKGROUND_COLOR");
  }


  ////////////////////////////////////////////////////////////////////////////
  // GUI - ACCORDION
  ////////////////////////////////////////////////////////////////////////////
  cp5.addAccordion("acc").setPosition(gui_x, gui_y).setWidth(gui_w).setSize(gui_w, height)
    .setCollapseMode(Accordion.MULTI)
    .addItem(group_fluid)
    .addItem(group_display)
    .open(4);
}






public class ObstaclePainter {

  // 0 ... not drawing
  // 1 ... adding obstacles
  // 2 ... removing obstacles
  public int draw_mode = 0;
  PGraphics pg;

  float size_paint = 15;
  float size_clear = size_paint * 2.5f;

  float paint_x, paint_y;
  float clear_x, clear_y;

  int shading = 64;

  public ObstaclePainter(PGraphics pg) {
    this.pg = pg;
  }

  public void beginDraw(int mode) {
    paint_x = mouseX;
    paint_y = mouseY;
    this.draw_mode = mode;
    if (mode == 1) {
      pg.beginDraw();
      pg.blendMode(REPLACE);
      pg.noStroke();
      pg.fill(shading);
      pg.ellipse(mouseX, mouseY, size_paint, size_paint);
      pg.endDraw();
    }
    if (mode == 2) {
      clear(mouseX, mouseY);
    }
  }

  public boolean isDrawing() {
    return draw_mode != 0;
  }

  public void draw() {
    paint_x = mouseX;
    paint_y = mouseY;
    if (draw_mode == 1) {
      pg.beginDraw();
      pg.blendMode(REPLACE);
      pg.strokeWeight(size_paint);
      pg.stroke(shading);
      pg.line(mouseX, mouseY, pmouseX, pmouseY);
      pg.endDraw();
    }
    if (draw_mode == 2) {
      clear(mouseX, mouseY);
    }
  }

  public void endDraw() {
    this.draw_mode = 0;
  }

  public void clear(float x, float y) {
    clear_x = x;
    clear_y = y;
    pg.beginDraw();
    pg.blendMode(REPLACE);
    pg.noStroke();
    pg.fill(0, 0);
    pg.ellipse(x, y, size_clear, size_clear);
    pg.endDraw();
  }

  public void displayBrush(PGraphics dst) {
    if (draw_mode == 1) {
      dst.strokeWeight(1);
      dst.stroke(0);
      dst.fill(200, 50);
      dst.ellipse(paint_x, paint_y, size_paint, size_paint);
    }
    if (draw_mode == 2) {
      dst.strokeWeight(1);
      dst.stroke(200);
      dst.fill(200, 100);
      dst.ellipse(clear_x, clear_y, size_clear, size_clear);
    }
  }
}

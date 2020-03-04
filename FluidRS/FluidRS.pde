/**
 * 
 * PixelFlow | Copyright (C) 2017 Thomas Diewald - http://thomasdiewald.com
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

import processing.core.*;
import processing.opengl.PGraphics2D;
import spout.Spout;

import spout.*;

PGraphics pgr; // Canvas to receive a texture
PImage img; // Image to receive a texture
PGraphics2D obstacleDrawing;



// Density is fed by a PGraphics object each frame.
// Spout is used to receive texture data from any external sender.
// 
// Note: 
// run sketch "Fluid_SpoutSender" to send a texture
// run sketch "Fluid_SpoutReceiver" to receive a texture
//
// this requires to have the "Spout for Processing" library installed:
// https://github.com/leadedge/SpoutProcessing/releases
// install manually, or the PDE-Contribution-Manager
//
// controls:
//
// LMB: add Velocity
// MMB: add Density
// RMB: add Temperature


private class MyFluidData implements DwFluid2D.FluidData {

  @Override
    public void update(DwFluid2D fluid) {

    if (mousePressed ) {
      float vscale = 5;
      float px     = mouseX;
      float py     = height - 1 - mouseY;
      float vx     = (mouseX - pmouseX) * +vscale;
      float vy     = (mouseY - pmouseY) * -vscale;

      if (mouseButton == LEFT) {
        fluid.addVelocity(px, py, 100, vx, vy);
      }
      if (mouseButton == CENTER) {
        //fluid.addDensity(px, py, 50, 1, 1, 1, 1, 1);
        //fluid.
        obstacleDrawing.beginDraw();
        pushStyle();
        obstacleDrawing.stroke(64);
        obstacleDrawing.fill(64);
        obstacleDrawing.ellipse(mouseX, mouseY, 30, 30);
        popStyle();
        obstacleDrawing.endDraw();
        fluid.addObstacles((PGraphics2D) obstacleDrawing);
      }
      if (mouseButton == RIGHT) {
        //fluid.addTemperature(px, py, 15, 10);

        spout.selectSender();
      }
    }


    //fluid.addTemperature(0, 0, 50, 10);
    //fluid.addTemperature(fluid.fluid_w, 0, 50, 10);

    //
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



Spout spout;
Spout sender;



DwPixelFlow context;

DwFluid2D fluid;
DwFluidParticleSystem2D particles;

PGraphics2D pg_fluid;         // primary fluid render target
PGraphics2D pg_density_input; // texture buffer for adding density


public void settings() {
  size(800, 800, P2D);
  smooth(8);
}


public void setup() {
  surface.setResizable(true);
  pgr = createGraphics(width, height, PConstants.P2D);
  img = createImage(width, height, ARGB);
  sender = new Spout(this);
  sender.createSender("FluidRSOut");

  surface.setLocation(250, 0);

  // main library context
  context = new DwPixelFlow(this);
  context.print();
  context.printGL();

  // fluid simulation
  fluid = new DwFluid2D(context, width, height, 1);

  // some fluid parameters
  fluid.param.dissipation_density     = 0.99f;
  fluid.param.dissipation_velocity    = 0.95f;
  fluid.param.dissipation_temperature = 5.70f;
  fluid.param.vorticity               = 1.50f;

  // interface for adding data to the fluid simulation
  MyFluidData cb_fluid_data = new MyFluidData();
  fluid.addCallback_FluiData(cb_fluid_data);

  // fluid render target
  pg_fluid = (PGraphics2D) createGraphics(width, height, P2D);
  pg_fluid.smooth(8);

  // particles
  particles = new DwFluidParticleSystem2D();
  particles.resize(context, width/4, height/4);

  // image/buffer that will be used as density input
  pg_density_input = (PGraphics2D) createGraphics(width, height, P2D);
  pg_density_input.smooth(0);
  pg_density_input.beginDraw();
  pg_density_input.clear();
  pg_density_input.endDraw();

  // spout
  spout = new Spout(this);
    spout.createReceiver("FluidRSIn");

  obstacleDrawing = (PGraphics2D) createGraphics(width, height, P2D);
  obstacleDrawing.smooth(0);
  obstacleDrawing.beginDraw();
  //pushStyle();
  //obstacleDrawing.stroke(255);
  //obstacleDrawing.fill(255);
  //obstacleDrawing.rect(0, 0, width, height);
  //popStyle();
  obstacleDrawing.clear();
  obstacleDrawing.endDraw();

  frameRate(120);
}


public void draw() {

  // get density input from spout
  spout.receiveTexture(pg_density_input);

  float angle = millis() * 0.001;
  float emitterPower = 50;
  float x = cos(angle) * emitterPower;
  float y = sin(angle) * emitterPower;
  
  fluid.addVelocity(width /2 - 100, height / 2 - 100, 100, x, y);


  // update fluid
  fluid.update();
  particles.update(fluid);

  // render fluid
  pg_fluid.beginDraw();
  pg_fluid.background(0);
  pg_fluid.endDraw();



  fluid.renderFluidTextures(pg_fluid, 0);
  //    particles.render(pg_fluid, null, 2);

  // display result
  image(pg_fluid, 0, 0);

  sender.sendTexture();
  
  //image(obstacleDrawing, 0, 0);
}


public void keyReleased() {
  if (key == 'r') fluid.reset();
}
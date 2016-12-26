import processing.serial.*;
import processing.sound.*;
import java.util.List;

public static final int WINDOW_WIDTH = 1080;
public static final int WINDOW_HEIGHT = 720;

Serial test_serial;
Serial engduino;
TitleScreen start_screen;
Player player;
Environment environment;

SoundFile main_theme;
SoundFile missile_sound;
SoundFile explosion_sound;
SoundFile deflection_sound;
SoundFile damage_sound;
SoundFile game_start_sound;
SoundFile game_over_sound;

public class GameObject
{
  // stores horizontal and vertical component of position and velocity
  float[] position, velocity;
  PImage sprite;
  
  public GameObject()
  {
    position = new float[2];
    velocity = new float[2];
  }
  
  public float[] getPos()
  {
    return position;
  }
  
  public void updatePos()
  {
    position[0] += velocity[0];
    position[1] += velocity[1];
    return;
  }
  
  public void drawObject()
  {
    image(sprite, position[0], position[1]);
    return;
  }
  
}

public class Player extends GameObject
{
  static final int WIDTH = 70;
  static final int HEIGHT = 50;
  
  float acceleration;
  int lives;
  boolean invincible;
  Clock invincibility_timer;
  
  public Player()
  {
    lives = 3;
    invincible = false;
    invincibility_timer = new Clock();
    position[0] = (WINDOW_WIDTH / 2) - (WIDTH / 2);
    position[1] = WINDOW_HEIGHT - HEIGHT;
    velocity[0] = 0;
    velocity[1] = 0;
    acceleration = 0;
    sprite = loadImage("engduino.png");
  }
  
  public void updatePos()
  {
    velocity[0] += acceleration;
    float new_pos = position[0] + (4 * velocity[0]);
    
    // if player is too far to the left or right, bounce them back on the screen
    if (new_pos < 0)
    {
      new_pos = 0;
      velocity[0] *= -0.3;
    }
    else if (new_pos > WINDOW_WIDTH - WIDTH)
    {
      new_pos = WINDOW_WIDTH - WIDTH;
      velocity[0] *= -0.3;
    }
    
    position[0] = new_pos;
    return;
  }
  
  public void drawObject()
  {
    // if player is invincible, they will "blink" at 0.5 second intervals
    if (!(invincible && invincibility_timer.timePassed() % 500 < 250))
    {
      image(sprite, position[0], position[1]);
    }
    return;
  }
  
  public void updateAcc(String inBuffer)
  {
    // acceleration value passed from Engduino's accelerometer
    acceleration = 0.1 * Float.parseFloat(inBuffer.substring(1));
    return;
  }
  
  // decreases health & makes player invincible for 2 seconds after taking damage
  public void takeDamage()
  {
    lives--;
    invincible = true;
    invincibility_timer.resetTimer();
    damage_sound.play();
    if (lives <= 0)
    {
      environment.playerDied();
    }
    return;
  }
  
  public void checkInvincibility()
  {
    if (!invincible || invincibility_timer.timePassed() > 2000)
    {
      invincible = false;
    }
    return;
  }
  
  public boolean isInvincible()
  {
    return invincible;
  }
  
  public int getHealth()
  {
    return lives;
  }
  
}

public class Missile extends GameObject
{
  static final int WIDTH = 10;
  static final int HEIGHT = 20;
  
  public Missile()
  {
    position[0] = player.getPos()[0] + (Player.WIDTH / 2);
    position[1] = WINDOW_HEIGHT - Player.HEIGHT - 10;
    velocity[0] = 0;
    velocity[1] = -7;
    sprite = loadImage("missile.png");
    missile_sound.play();
    environment.addMissile(this);
  }
}

public class Enemy extends GameObject
{
  static final int WIDTH = 39;
  static final int HEIGHT = 40;
  String type;
  
  public Enemy()
  {
    position[0] = random(1060);
    position[1] = HEIGHT * -1;
    environment.addEnemy(this);
  }
  
  public String getType()
  {
    return type;
  }
}

public class Alien extends Enemy
{ 
  public Alien()
  {
    type = "alien";
    velocity[0] = 0;
    velocity[1] = int(random(8));
    sprite = loadImage("alien.png");
  }
}

public class Asteroid extends Enemy
{
  public Asteroid()
  {
    type = "asteroid";
    velocity[0] = int(random(-6, 6));
    velocity[1] = int(random(8));
    sprite = loadImage("asteroid.png");
  }
  
  public void updatePos()
  {
    float new_x = position[0] + velocity[0];
    
    // if asteroid has moved to a horizontal edge of the screen, bounce it back
    if (new_x < 0 || new_x + WIDTH > WINDOW_WIDTH)
    {
      velocity[0] *= -1;
    }
    position[0] = new_x;
    position[1] += velocity[1];
    return;
  }
}

public class Explosion extends GameObject
{
  Clock explosion_timer;
  PImage[] sprite_frames;
  int frame_index;
  
  public Explosion(float[] alien_position)
  {
    explosion_timer = new Clock();
    sprite_frames = new PImage[3];
    
    // explosion will be drawn in the position of the dead alien
    position[0] = alien_position[0];
    position[1] = alien_position[1];
    sprite_frames[0] = loadImage("explosion1.png");
    sprite_frames[1] = loadImage("explosion2.png");
    sprite_frames[2] = loadImage("explosion3.png");
    frame_index = 0;
    
    explosion_sound.play();
    environment.addExplosion(this);
  }
  
  public void drawObject()
  {
    // draw each of the explosion's frames at 0.3-second intervals
    if (explosion_timer.timePassed() > 300)
    {
      if (frame_index > 1)
      {
        environment.removeExplosion(this);
        return;
      }
      else
      {
        frame_index++;
      }
      
    }
    image(sprite_frames[frame_index], position[0], position[1]);
    return;
  }
}

public class Environment
{
  ArrayList<Missile> missiles = new ArrayList<Missile>();
  ArrayList<Enemy> enemies = new ArrayList<Enemy>();
  ArrayList<Explosion> explosions = new ArrayList<Explosion>();
  Clock game_timer, star_timer, spawn_timer;
  PImage heart;
  boolean game_over;
  boolean[][] stars;
  int[] spawn_interval = {5000, 4000, 3000, 3500, 2000, 1500, 1250, 1000, 750, 500, 250};
  int difficulty, score;
  
  public Environment()
  {
    star_timer = new Clock();
    game_over = false;
    
    // set up initial star grid; true means a star will be drawn in that position
    stars = new boolean[WINDOW_HEIGHT / 12][WINDOW_WIDTH / 4];
    for (int i = 0; i < WINDOW_HEIGHT / 12; i++)
    {
      for (int j = 0; j < WINDOW_WIDTH / 4; j++)
      {
        if (int(random(30)) == 1)
        {
          stars[i][j] = true;
        }
      }
    }
  }
  
  void startGame()
  {
    game_timer = new Clock();
    spawn_timer = new Clock();
    heart = loadImage("heart.png");
    score = difficulty = 0;
    return;
  }
  
  void engduinoIO()
  {
    // read input from engduino
    String inBuffer = engduino.readStringUntil('\n');
    if (inBuffer != null)
    {
      if (inBuffer.charAt(0) == 'y')
      {
        player.updateAcc(inBuffer);
      }
      else if (inBuffer.charAt(0) == 'F')
      {
        new Missile();
      }  
    }

    return;
  }
  
  public void updatePositions()
  {
    int i, j;
    player.updatePos();
    
    for (i = 0; i < missiles.size(); i++)
    {
      missiles.get(i).updatePos();
    } 
    
    for (i = 0; i < enemies.size(); i++)
    {
      enemies.get(i).updatePos();
    }
    
    // scroll stars forward every 0.03 seconds
    if (star_timer.timePassed() > 30)
    {
      star_timer.resetTimer();
      
      // save the current top row of stars
      boolean[] last_row = new boolean[WINDOW_WIDTH / 4];
      for (i = 0; i < WINDOW_WIDTH / 4; i++)
      {
        last_row[i] = stars[0][i];
      }
      
      // shift each row of stars (except the top and bottom ones) up by one position
      for (i = 0; i < (WINDOW_HEIGHT / 12) - 1; i ++)
      {
        for (j = 0; j < WINDOW_WIDTH / 4; j++)
        {
          stars[i][j] = stars[i + 1][j];
        }
      }
      
      // set the new bottom row to be the old top row
      for (i = 0; i < WINDOW_WIDTH / 4; i++)
      {
        stars[(WINDOW_HEIGHT / 12) - 1][i] = last_row[i]; 
      }  
    }
    return;
  }
  
  public void collisionDetect()
  {
    int i, j;
    for (i = 0; i < enemies.size(); i++)
    {
      for (j = 0; j < missiles.size(); j++)
      {
        // if a missile and an enemy are vertically within range of each other
        if (abs(missiles.get(j).getPos()[1] - enemies.get(i).getPos()[1]) <= Enemy.HEIGHT)
        {
          // and are also horizontally within range, from either the left OR the right side
          if ((missiles.get(j).getPos()[0] <= enemies.get(i).getPos()[0]
               && enemies.get(i).getPos()[0] - missiles.get(j).getPos()[0] + Missile.WIDTH <= Enemy.WIDTH)
               || (missiles.get(j).getPos()[0] >= enemies.get(i).getPos()[0]
               && missiles.get(j).getPos()[0] - enemies.get(i).getPos()[0] <= Enemy.WIDTH))
          {
            missiles.remove(j);
            
            // if the hit enemy is an alien, it dies
            if (enemies.get(i).getType().equals("alien"))
            {
              new Explosion(enemies.get(i).getPos());
              enemies.remove(i);
              score += 50;
              break;
            }
            else
            {
              deflection_sound.play();
            }
          }
        }
      }
    }
    
    // remove enemies or missiles that have moved outside the screen
    for (i = 0; i < enemies.size(); i++)
    {
      if (enemies.get(i).getPos()[1] > WINDOW_HEIGHT)
      {
        if (enemies.get(i).getType().equals("asteroid"))
        {
          score += 10;
        }
        enemies.remove(i);
      }
    }
    if (missiles.size() > 0)
    {
      if (missiles.get(0).getPos()[1] < 0)
      {
        missiles.remove(0);
      }
    }
    
    player.checkInvincibility();
    
    // check if player has been hit by an enemy
    for (i = 0; i < enemies.size(); i++)
    {
    // if the player and an enemy are vertically within range and player is not invincible
      if (player.getPos()[1] - enemies.get(i).getPos()[1] <= Enemy.HEIGHT && !player.isInvincible())
      {
        // and they are also horizontally within range, from either the left OR the right side
        if ((player.getPos()[0] <= enemies.get(i).getPos()[0]
               && enemies.get(i).getPos()[0] - player.getPos()[0] + Player.WIDTH <= Enemy.WIDTH)
               || (player.getPos()[0] >= enemies.get(i).getPos()[0]
               && player.getPos()[0] - enemies.get(i).getPos()[0] <= Enemy.WIDTH))
        {
          player.takeDamage();
        }
      }
    }  
  }
  
  public void spawnEnemies()
  {
    // difficulty variable controls frequency at which enemies spawn
    if (spawn_timer.timePassed() > spawn_interval[difficulty])
    {
      if (int(random(2)) == 0)
      {
        new Alien();
      }
      else
      {
        new Asteroid();
      }
      spawn_timer.resetTimer();
    }
    
    // every 15 seconds, increase difficulty
    if (game_timer.timePassed() > 15000 && difficulty < 10)
    {
      difficulty++;
      game_timer.resetTimer();
    }
  }
  
  public void drawBackground()
  {
    background(0);
    
    // draw star grid
    for (int i = 0; i < WINDOW_HEIGHT / 12; i++)
    {
      for (int j = 0; j < WINDOW_WIDTH / 4; j++)
      {
        if (stars[i][j])
        {
          stroke(91, 91, 91);
          fill(91, 91, 91);
          rect(j * 4, i * 12, 4, 12);
        }
      }
    }  
  }
  
  public void drawHUD()
  {
    // draw player's health
    fill(255, 0, 0);
    text("Health", 990, 30);
    for (int i = 0; i < 3; i++)
    {
      if (player.getHealth() > i)
      {
        image(heart, WINDOW_WIDTH - (30 * (3 - i)), 40);
      }
    }
    
    // draw current score
    fill(255, 230, 0);
    text("Score", 5, 30);
    fill(255);
    text(score, 5, 63);
    
    return;
  }
  
  public void drawObjects()
  {
    int i;
    for (i = 0; i < missiles.size(); i++)
    {
      missiles.get(i).drawObject();
    }
    
    for (i = 0; i < enemies.size(); i++)
    {
      enemies.get(i).drawObject();
    }
    
    for (i = 0; i < explosions.size(); i++)
    {
      explosions.get(i).drawObject();
    }
    
    player.drawObject();
    return;
  }
  
  public void addMissile(Missile newMissile)
  {
    missiles.add(newMissile);
    return;
  }
  
  public void addEnemy(Enemy newEnemy)
  {
    enemies.add(newEnemy);
    return;
  }
  
  public void addExplosion(Explosion newExplosion)
  {
    explosions.add(newExplosion);
    return;
  }
  
  public void removeExplosion(Explosion explosion)
  {
    explosions.remove(explosion);
    return;
  }
  
  public boolean isGameOver()
  {
    return game_over;
  }
  
  public void playerDied()
  {
    game_over = true;
    main_theme.stop();
    return;
  }
  
  public void gameOverScreen()
  {
    delay(450);
    fill(255);
    textSize(100);
    textAlign(CENTER);
    text("GAME OVER", WINDOW_WIDTH / 2, WINDOW_HEIGHT / 2);
    textSize(40);
    fill(255, 230, 0);
    text("Final score:", WINDOW_WIDTH / 2, (WINDOW_HEIGHT / 2) + 60);
    textSize(70);
    fill(255);
    text(score, WINDOW_WIDTH / 2, (WINDOW_HEIGHT / 2) + 140);
    game_over_sound.play();
    noLoop();
    return;
  }
}

public class Clock
{
  int timer;
  
  public Clock()
  {
    timer = millis();
  }
  
  public int timePassed()
  {
    return millis() - timer;
  }
  
  public void resetTimer()
  {
    timer = millis();
    return;
  }
}

public class TitleScreen
{
  PImage title_screen;
  boolean game_ready, usb_available, engduino_available;
  
  public TitleScreen(boolean serial_found, boolean engduino_found)
  {
    usb_available = serial_found;
    engduino_available = engduino_found;
    title_screen = loadImage("title_screen.png");
    game_ready = false;
  }
  
  public void showTitle()
  {
    image(title_screen, 0, 0);
  }
  
  public void printMessage()
  {
    // draw text box
    fill(0);
    stroke(255, 255, 255);
    rect((WINDOW_WIDTH / 2) - 200, (WINDOW_HEIGHT / 2), 400, 260);
    
    textSize(26);
    if (!usb_available || !engduino_available)
    {
      fill(255, 0, 0);
      if (!usb_available)
      {
        text("No USB device found.", (WINDOW_WIDTH / 2) - 190,  ((WINDOW_HEIGHT / 2) + 50));
      }
      else if (!engduino_available)
      {
        text("Engduino not detected.", (WINDOW_WIDTH / 2) - 190,  ((WINDOW_HEIGHT / 2) + 50));
      }
      text("Please plug an Engduino with", (WINDOW_WIDTH / 2) - 190,  ((WINDOW_HEIGHT / 2) + 110));
      text("the \"interstellar_engduino.ino\" ", (WINDOW_WIDTH / 2) - 190,  ((WINDOW_HEIGHT / 2) + 140));
      text("program installed into your", (WINDOW_WIDTH / 2) - 190,  ((WINDOW_HEIGHT / 2) + 170));
      text("computer's USB port and", (WINDOW_WIDTH / 2) - 190,  ((WINDOW_HEIGHT / 2) + 200));
      text("reboot the game.", (WINDOW_WIDTH / 2) - 190,  ((WINDOW_HEIGHT / 2) + 230));
    }
    else
    {
      fill(0, 186, 46);
      text("Engduino detected!", (WINDOW_WIDTH / 2) - 120,  ((WINDOW_HEIGHT / 2) + 50));
      text("Press the Engduino button" , (WINDOW_WIDTH / 2) - 170,  ((WINDOW_HEIGHT / 2) + 120));
      text("to start the game.", (WINDOW_WIDTH / 2) - 170, ((WINDOW_HEIGHT / 2) + 160));
    }
    return;
  }
  
  // starts game if Engduino has been detected and player has pressed button
  public void waitForPlayerStart()
  {
    if (engduino_available)
    {
      String inBuffer = engduino.readStringUntil('\n');
      if (inBuffer != null)
      {
        if (inBuffer.charAt(0) == 'F')
        {
          game_ready = true;
          game_start_sound.play();
          environment.startGame();
        }
      }
    }
    return;
  }
  
  public boolean gameStarted()
  {
    return game_ready;
  }
}

void settings()
{
  size(WINDOW_WIDTH, WINDOW_HEIGHT);
}

void setup()
{ 
  environment = new Environment();
  player = new Player();
  
  // initialise music and sound effects
  main_theme = new SoundFile(this, "main_theme.mp3");
  game_start_sound = new SoundFile(this, "start_game.wav");
  game_over_sound = new SoundFile(this, "game_over.wav");
  missile_sound = new SoundFile(this, "missile.wav");
  explosion_sound = new SoundFile(this, "explosion.wav");
  deflection_sound = new SoundFile(this, "deflection.wav");
  damage_sound = new SoundFile(this, "damage.wav");
  
  main_theme.loop();
  
  boolean serial_found, engduino_found;
  serial_found = engduino_found = false;
  
  // check to see which serial port is available
  for (int i = 0; i < Serial.list().length; i++)
  {
    test_serial = new Serial(this, Serial.list()[i]);
    delay(500);
    if (test_serial.available() > 0)
    {
      serial_found = true;
      break;
    } 
  }
  
  // check to see if Engduino is plugged in and broadcasting legitimate signals
  if (serial_found)
  {
    // read input from serial port
    String inBuffer = test_serial.readStringUntil('\n');
    
    // if the serial device is sending 'F' or 'y', then we assume it is the Engduino
    if ("Fy".indexOf(inBuffer.charAt(0)) > -1)
    {
      engduino = test_serial;
      engduino_found = true;
    }
  }
  
  start_screen = new TitleScreen(serial_found, engduino_found);
}

void draw()
{
  if (start_screen.gameStarted() && !environment.isGameOver())
  {
    environment.engduinoIO();
    environment.updatePositions();
    environment.collisionDetect();
    environment.spawnEnemies();
    environment.drawBackground();
    environment.drawObjects();
    environment.drawHUD();
  }
  else if (!environment.isGameOver())
  {
    environment.updatePositions();
    environment.drawBackground();
    start_screen.showTitle();
    start_screen.printMessage();
    start_screen.waitForPlayerStart();
  }
  else
  {
    environment.gameOverScreen();
  }
}
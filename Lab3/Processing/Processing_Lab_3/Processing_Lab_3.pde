
import processing.serial.*;

Serial arduino;

float playerX = 300;
float playerY = 300;

float speed = 4;
int playerSize = 40;

char direction = 'S';

void setup() {
  size(600, 600);

  println(Serial.list());

  // Change the port index to your FireBeetle.
  arduino = new Serial(this, Serial.list()[0], 115200);
  arduino.bufferUntil('\n');

  rectMode(CENTER);
}

void draw() {
  background(245);

  // Move player
  if (direction == 'U') {
    playerY -= speed;
  }
  else if (direction == 'D') {
    playerY += speed;
  }
  else if (direction == 'L') {
    playerX -= speed;
  }
  else if (direction == 'R') {
    playerX += speed;
  }

  // Keep player inside window
  playerX = constrain(playerX, 20, width - 20);
  playerY = constrain(playerY, 20, height - 20);

  // Draw player
  fill(40, 120, 230);
  noStroke();
  rect(playerX, playerY, playerSize, playerSize, 6);

  // Display direction
  fill(30);
  textAlign(CENTER);
  textSize(20);
  text("Direction: " + direction, width / 2, 40);

  textSize(14);
  text("Control the square with your smart tattoo",
       width / 2, height - 25);
}

void serialEvent(Serial port) {
  String input = port.readStringUntil('\n');

  if (input != null) {
    input = trim(input);

    if (input.length() == 1) {
      char command = input.charAt(0);

      if (command == 'U' || command == 'D' ||
          command == 'L' || command == 'R' ||
          command == 'S') {
        direction = command;
      }
    }
  }
}

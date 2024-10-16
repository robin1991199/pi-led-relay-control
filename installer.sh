#!/bin/bash

# Define project directory
PROJECT_DIR=~/led_controller
TEMPLATES_DIR=$PROJECT_DIR/templates
STATIC_DIR=$PROJECT_DIR/static

# Function to check if a command was successful
check_success() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Update package list and install necessary packages
echo "Updating package list and installing necessary packages..."
sudo apt update
check_success "Failed to update package list"
sudo apt install -y python3-flask python3-rpi.gpio
check_success "Failed to install required packages"

# Create project directory structure
echo "Creating project directory and folders..."
mkdir -p $TEMPLATES_DIR
mkdir -p $STATIC_DIR/css
mkdir -p $STATIC_DIR/js

# Create the main app.py file
cat <<EOL > $PROJECT_DIR/app.py
from flask import Flask, render_template, request, redirect, url_for, session, flash
import RPi.GPIO as GPIO
import os

app = Flask(__name__)
app.secret_key = os.urandom(24)  # Secret key for session management

# User credentials (for demonstration purposes)
USER_CREDENTIALS = {
    'username': 'admin',
    'password': 'password'  # Change this to something more secure
}

# Set up GPIO
LED_PIN = 11
RELAY_PINS = [2, 3, 4, 17, 27, 22, 10, 9]
GPIO.setmode(GPIO.BCM)
GPIO.setup(LED_PIN, GPIO.OUT)
for pin in RELAY_PINS:
    GPIO.setup(pin, GPIO.OUT)

# Initialize relay status
relay_status = ['OFF'] * len(RELAY_PINS)

@app.route('/')
def index():
    if 'username' not in session:
        return redirect(url_for('login'))
    return render_template('index.html', led_status='OFF', relay_status=relay_status)

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        if username == USER_CREDENTIALS['username'] and password == USER_CREDENTIALS['password']:
            session['username'] = username
            flash('Login successful!', 'success')
            return redirect(url_for('index'))
        else:
            flash('Invalid credentials. Please try again.', 'danger')
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.pop('username', None)
    flash('You have been logged out.', 'success')
    return redirect(url_for('login'))

@app.route('/led', methods=['POST'])
def control_led():
    action = request.form['action']
    GPIO.output(LED_PIN, GPIO.HIGH if action == 'OFF' else GPIO.LOW)
    return index()

@app.route('/relay', methods=['POST'])
def control_relay():
    relay_index = int(request.form['relay'])
    action = request.form['action']
    GPIO.output(RELAY_PINS[relay_index], GPIO.HIGH if action == 'OFF' else GPIO.LOW)
    relay_status[relay_index] = action
    return index()

@app.route('/shutdown', methods=['POST'])
def shutdown():
    GPIO.cleanup()
    return 'Shutting down...', 200

if __name__ == '__main__':
    try:
        app.run(host='0.0.0.0', port=5000)
    except KeyboardInterrupt:
        GPIO.cleanup()
EOL

# Create index.html
cat <<EOL > $TEMPLATES_DIR/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Relay Controller</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
</head>
<body>
    <div class="container">
        <h1>Relay Control</h1>
        <h2>LED Status: {{ led_status }}</h2>

        <form method="POST" action="/led">
            <button name="action" value="ON" type="submit">Turn LED ON</button>
            <button class="off-button" name="action" value="OFF" type="submit">Turn LED OFF</button>
        </form>

        <div>
            {% for i in range(8) %}
                <div>
                    <h3>Relay {{ i + 1 }} - Status: {{ relay_status[i] }}</h3>
                    <form method="POST" action="/relay">
                        <input type="hidden" name="relay" value="{{ i }}">
                        <button name="action" value="ON" type="submit">Turn ON</button>
                        <button class="off-button" name="action" value="OFF" type="submit">Turn OFF</button>
                    </form>
                </div>
            {% endfor %}
        </div>

        <footer>
            <p>Control the relays and LED using the buttons above.</p>
            <form method="POST" action="/logout">
                <button type="submit">Logout</button>
            </form>
        </footer>
    </div>
</body>
</html>
EOL

# Create login.html
cat <<EOL > $TEMPLATES_DIR/login.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
</head>
<body>
    <div class="login-container">
        <h2>Login</h2>
        {% with messages = get_flashed_messages(with_categories=true) %}
          {% if messages %}
            {% for category, message in messages %}
              <div class="message">{{ message }}</div>
            {% endfor %}
          {% endif %}
        {% endwith %}
        <form method="POST" action="/login">
            <input type="text" name="username" placeholder="Username" required>
            <input type="password" name="password" placeholder="Password" required>
            <button type="submit">Login</button>
        </form>
    </div>
</body>
</html>
EOL

# Create a CSS file for styling
cat <<EOL > $STATIC_DIR/css/style.css
body {
    font-family: 'Arial', sans-serif;
    background-image: url('https://mir-s3-cdn-cf.behance.net/project_modules/fs/5278b973057517.5bfd226687bb7.jpg');
    background-size: cover;
    color: white;
    text-align: center;
}

.container {
    padding: 20px;
}

button {
    padding: 10px;
    margin: 5px;
    cursor: pointer;
    width: auto; /* Set button width to auto */
    display: inline-block; /* Change display to inline-block for button alignment */
}

footer {
    margin-top: 20px;
}

.login-container {
    background-color: white;
    padding: 40px;
    border-radius: 10px;
    box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
    width: 300px;
    margin: auto; /* Center the login container */
}

input[type="text"], input[type="password"] {
    width: 100%;
    padding: 10px;
    margin: 10px 0;
    border: 1px solid #ccc;
    border-radius: 5px;
}

button {
    width: auto; /* Set button width to auto */
    padding: 10px 20px; /* Padding adjusted for better appearance */
    background-color: #4CAF50; /* Green background for ON buttons */
    color: white; /* Text color */
    border: none; /* No border */
    border-radius: 5px; /* Rounded corners */
    cursor: pointer; /* Pointer on hover */
}

button:hover {
    opacity: 0.8; /* Slightly reduce opacity on hover */
}

.off-button {
    background-color: red; /* Red background for OFF buttons */
    padding: 10px 20px; /* Consistent padding */
    color: white; /* Text color */
    border: none; /* No border */
    border-radius: 5px; /* Rounded corners */
    cursor: pointer; /* Pointer on hover */
}

.off-button:hover {
    opacity: 0.8; /* Slightly reduce opacity on hover */
}

.message {
    color: red;
}
EOL

# Create the run.sh script
cat <<EOL > $PROJECT_DIR/run.sh
#!/bin/bash
export FLASK_APP=app.py
export FLASK_ENV=development
flask run --host=0.0.0.0
EOL

chmod +x $PROJECT_DIR/run.sh

# Create the uninstall script
cat <<EOL > $PROJECT_DIR/uninstall.sh
#!/bin/bash

# Remove project directory
echo "Removing project directory..."
rm -rf $PROJECT_DIR

# Optionally remove Flask if not needed
echo "Flask will not be removed, as it may be required by other applications."

echo "Uninstallation complete."
EOL

chmod +x $PROJECT_DIR/uninstall.sh

# Print success message
echo "Installation complete! Run the application using './run.sh' in the $PROJECT_DIR directory."

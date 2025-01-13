# Use the latest Debian base image
FROM debian:latest

# Install necessary packages
RUN apt-get update && apt-get install -y \
    qemu-system \
    qemu-utils \
    python3 \
    python3-pip \
    python3-venv \
    xvfb \
    novnc \
    websockify \
    git \
    supervisor \
    && apt-get clean

# Create and activate a virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Flask
RUN pip install Flask

# Create app directory
RUN mkdir -p /app

# Set working directory
WORKDIR /app

# Copy Flask application code
RUN echo "\
import os\n\
from flask import Flask, request, redirect, url_for, render_template\n\
from werkzeug.utils import secure_filename\n\
import subprocess\n\
\n\
app = Flask(__name__)\n\
app.config['UPLOAD_FOLDER'] = '/app'\n\
app.config['MAX_CONTENT_LENGTH'] = 3 * 1024 * 1024 * 1024  # 3GB limit\n\
\n\
ALLOWED_EXTENSIONS = {'iso'}\n\
\n\
def allowed_file(filename):\n\
    return '.' in filename and \\\n\
           filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS\n\
\n\
@app.route('/')\n\
def index():\n\
    return render_template('index.html')\n\
\n\
@app.route('/upload', methods=['POST'])\n\
def upload_file():\n\
    if 'file' not in request.files:\n\
        return redirect(request.url)\n\
    file = request.files['file']\n\
    if file and allowed_file(file.filename):\n\
        filename = secure_filename(file.filename)\n\
        file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))\n\
        return redirect(url_for('customize_drive', filename=filename))\n\
    return redirect(request.url)\n\
\n\
@app.route('/customize', methods=['GET', 'POST'])\n\
def customize_drive():\n\
    if request.method == 'POST':\n\
        drive_name = secure_filename(request.form['drive_name'])\n\
        drive_size = request.form['drive_size']\n\
        drive_format = request.form['drive_format']\n\
        iso_file = request.form['iso_file']\n\
\n\
        drive_filename = f\"{drive_name}.{drive_format}\"\n\
        drive_path = os.path.join(app.config['UPLOAD_FOLDER'], drive_filename)\n\
\n\
        # Create the drive\n\
        if drive_format == 'img':\n\
            subprocess.run(['qemu-img', 'create', '-f', 'raw', drive_path, f\"{drive_size}G\"])\n\
        elif drive_format == 'qcow2':\n\
            subprocess.run(['qemu-img', 'create', '-f', 'qcow2', drive_path, f\"{drive_size}G\"])\n\
\n\
        # Save the ISO file name for use in supervisor config\n\
        with open('/app/boot.iso', 'w') as f:\n\
            f.write(iso_file)\n\
\n\
        return redirect(url_for('start_vm', drive_filename=drive_filename))\n\
\n\
    iso_file = request.args.get('filename')\n\
    return render_template('customize.html', iso_file=iso_file)\n\
\n\
@app.route('/start_vm')\n\
def start_vm():\n\
    drive_filename = request.args.get('drive_filename')\n\
\n\
    # Update supervisord.conf with the correct drive file\n\
    with open('/app/supervisord.conf', 'w') as f:\n\
        f.write(\"\"\"\n\
[supervisord]\n\
nodaemon=true\n\
\n\
[program:qemu]\n\
command=xvfb-run -a qemu-system-x86_64 -m 2G -enable-kvm -vnc :0 -hda /app/\"\"\" + drive_filename + \"\"\" -cdrom /app/boot.iso -boot d\n\
stdout_logfile=/dev/fd/1\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/fd/2\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:websockify]\n\
command=websockify --web=/usr/share/novnc/ 5900 localhost:5900\n\
stdout_logfile=/dev/fd/1\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/fd/2\n\
stderr_logfile_maxbytes=0\n\
\"\"\")\n\
\n\
    # Start the VM\n\
    subprocess.run(['supervisorctl', 'start', 'qemu'])\n\
    return redirect(url_for('vnc'))\n\
\n\
@app.route('/vnc')\n\
def vnc():\n\
    return redirect('http://localhost:5900/vnc.html')\n\
\n\
if __name__ == '__main__':\n\
    app.run(host='0.0.0.0', port=5000)\n\
" > /app/app.py

# Copy HTML templates
RUN mkdir -p /app/templates
RUN echo "\
<!doctype html>\n\
<html lang='en'>\n\
<head>\n\
    <meta charset='utf-8'>\n\
    <title>Upload ISO</title>\n\
</head>\n\
<body>\n\
    <h1>Upload ISO File</h1>\n\
    <form action='/upload' method='post' enctype='multipart/form-data'>\n\
        <input type='file' name='file'>\n\
        <input type='submit' value='Upload'>\n\
    </form>\n\
</body>\n\
</html>\n\
" > /app/templates/index.html

RUN echo "\
<!doctype html>\n\
<html lang='en'>\n\
<head>\n\
    <meta charset='utf-8'>\n\
    <title>Customize Drive</title>\n\
</head>\n\
<body>\n\
    <h1>Customize Drive</h1>\n\
    <form action='/customize' method='post'>\n\
        <input type='hidden' name='iso_file' value='{{ iso_file }}'>\n\
        <label for='drive_name'>Drive Name:</label>\n\
        <input type='text' id='drive_name' name='drive_name' required><br>\n\
        <label for='drive_size'>Drive Size (GB):</label>\n\
        <input type='number' id='drive_size' name='drive_size' required><br>\n\
        <label for='drive_format'>Drive Format:</label>\n\
        <select id='drive_format' name='drive_format'>\n\
            <option value='img'>IMG</option>\n\
            <option value='qcow2'>QCOW2</option>\n\
        </select><br>\n\
        <input type='submit' value='Create Drive'>\n\
    </form>\n\
    <form action='/start_vm' method='get'>\n\
        <input type='hidden' name='drive_filename' value='{{ drive_name }}.{{ drive_format }}'>\n\
        <input type='submit' value='Run VM'>\n\
    </form>\n\
</body>\n\
</html>\n\
" > /app/templates/customize.html

# Copy Supervisor configuration template
RUN echo "\
[supervisord]\n\
nodaemon=true\n\
\n\
[program:qemu]\n\
command=xvfb-run -a qemu-system-x86_64 -m 2G -enable-kvm -vnc :0 -hda /app/drive.img -cdrom /app/boot.iso -boot d\n\
stdout_logfile=/dev/fd/1\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/fd/2\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:websockify]\n\
command=websockify --web=/usr/share/novnc/ 5900 localhost:5900\n\
stdout_logfile=/dev/fd/1\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/fd/2\n\
stderr_logfile_maxbytes=0\n\
" > /app/supervisord.conf.template

# Copy the initial supervisord.conf file
RUN cp /app/supervisord.conf.template /app/supervisord.conf

# Expose ports
EXPOSE 5000 5900

# Start the application using Supervisor
CMD ["/usr/bin/supervisord", "-c", "/app/supervisord.conf"]

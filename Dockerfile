# Use the latest Debian image
FROM debian:latest

# Set environment variables to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list and install qemu, noVNC, and other dependencies
RUN apt-get update && \
    apt-get install -y qemu qemu-utils python3 python3-pip novnc websockify && \
    apt-get clean

# Install Flask
RUN pip3 install Flask

# Create the directory for the Flask application
RUN mkdir -p /app/uploads /app/templates /app/static

# Set the working directory
WORKDIR /app

# Add the Flask application code directly in the Dockerfile
RUN echo 'from flask import Flask, request, render_template, redirect, url_for' > app.py && \
    echo 'import os' >> app.py && \
    echo 'import subprocess' >> app.py && \
    echo '' >> app.py && \
    echo 'app = Flask(__name__)' >> app.py && \
    echo 'app.config["UPLOAD_FOLDER"] = "uploads"' >> app.py && \
    echo 'app.config["MAX_CONTENT_LENGTH"] = 2 * 1024 * 1024 * 1024  # Max file size: 2 GB' >> app.py && \
    echo '' >> app.py && \
    echo '# Ensure the upload folder exists' >> app.py && \
    echo 'os.makedirs(app.config["UPLOAD_FOLDER"], exist_ok=True)' >> app.py && \
    echo '' >> app.py && \
    echo '@app.route("/")' >> app.py && \
    echo 'def index():' >> app.py && \
    echo '    files = os.listdir(app.config["UPLOAD_FOLDER"])' >> app.py && \
    echo '    return render_template("index.html", files=files)' >> app.py && \
    echo '' >> app.py && \
    echo '@app.route("/upload", methods=["POST"])' >> app.py && \
    echo 'def upload_file():' >> app.py && \
    echo '    if "file" not in request.files:' >> app.py && \
    echo '        return redirect(request.url)' >> app.py && \
    echo '    file = request.files["file"]' >> app.py && \
    echo '    if file.filename == "":' >> app.py && \
    echo '        return redirect(request.url)' >> app.py && \
    echo '    if file:' >> app.py && \
    echo '        filepath = os.path.join(app.config["UPLOAD_FOLDER"], file.filename)' >> app.py && \
    echo '        file.save(filepath)' >> app.py && \
    echo '        return redirect(url_for("index"))' >> app.py && \
    echo '' >> app.py && \
    echo '@app.route("/run", methods=["POST"])' >> app.py && \
    echo 'def run_iso():' >> app.py && \
    echo '    iso_file = request.form["iso_file"]' >> app.py && \
    echo '    iso_path = os.path.join(app.config["UPLOAD_FOLDER"], iso_file)' >> app.py && \
    echo '    subprocess.Popen(["qemu-system-x86_64", "-cdrom", iso_path, "-vnc", ":1"])' >> app.py && \
    echo '    subprocess.Popen(["websockify", "5901", "localhost:5900"])' >> app.py && \
    echo '    return redirect(url_for("vnc_viewer"))' >> app.py && \
    echo '' >> app.py && \
    echo '@app.route("/create_drive", methods=["POST"])' >> app.py && \
    echo 'def create_drive():' >> app.py && \
    echo '    drive_name = request.form["drive_name"]' >> app.py && \
    echo '    drive_size = request.form["drive_size"]' >> app.py && \
    echo '    drive_path = os.path.join(app.config["UPLOAD_FOLDER"], drive_name)' >> app.py && \
    echo '    subprocess.run(["qemu-img", "create", "-f", "qcow2", drive_path, f"{drive_size}G"])' >> app.py && \
    echo '    return redirect(url_for("index"))' >> app.py && \
    echo '' >> app.py && \
    echo '@app.route("/vnc_viewer")' >> app.py && \
    echo 'def vnc_viewer():' >> app.py && \
    echo '    return render_template("vnc_viewer.html")' >> app.py && \
    echo '' >> app.py && \
    echo 'if __name__ == "__main__":' >> app.py && \
    echo '    app.run(host="0.0.0.0", port=5000)' >> app.py

# Add the HTML template directly in the Dockerfile
RUN echo '<!doctype html>' > templates/index.html && \
    echo '<html lang="en">' >> templates/index.html && \
    echo '<head>' >> templates/index.html && \
    echo '    <meta charset="UTF-8">' >> templates/index.html && \
    echo '    <meta name="viewport" content="width=device-width, initial-scale=1.0">' >> templates/index.html && \
    echo '    <title>Flask QEMU App</title>' >> templates/index.html && \
    echo '</head>' >> templates/index.html && \
    echo '<body>' >> templates/index.html && \
    echo '    <h1>Upload ISO File</h1>' >> templates/index.html && \
    echo '    <form action="/upload" method="post" enctype="multipart/form-data">' >> templates/index.html && \
    echo '        <input type="file" name="file">' >> templates/index.html && \
    echo '        <input type="submit" value="Upload">' >> templates/index.html && \
    echo '    </form>' >> templates/index.html && \
    echo '' >> templates/index.html && \
    echo '    <h1>Select ISO File to Run</h1>' >> templates/index.html && \
    echo '    <form action="/run" method="post">' >> templates/index.html && \
    echo '        <select name="iso_file">' >> templates/index.html && \
    echo '            {% for file in files %}' >> templates/index.html && \
    echo '            <option value="{{ file }}">{{ file }}</option>' >> templates/index.html && \
    echo '            {% endfor %}' >> templates/index.html && \
    echo '        </select>' >> templates/index.html && \
    echo '        <input type="submit" value="Run">' >> templates/index.html && \
    echo '    </form>' >> templates/index.html && \
    echo '' >> templates/index.html && \
    echo '    <h1>Create Virtual Hard Drive</h1>' >> templates/index.html && \
    echo '    <form action="/create_drive" method="post">' >> templates/index.html && \
    echo '        <input type="text" name="drive_name" placeholder="Drive name (e.g., drive.qcow2)">' >> templates/index.html && \
    echo '        <input type="text" name="drive_size" placeholder="Size in GB (e.g., 10)">' >> templates/index.html && \
    echo '        <input type="submit" value="Create">' >> templates/index.html && \
    echo '    </form>' >> templates/index.html && \
    echo '</body>' >> templates/index.html && \
    echo '</html>' >> templates/index.html

# Add the VNC viewer HTML template directly in the Dockerfile
RUN echo '<!doctype html>' > templates/vnc_viewer.html && \
    echo '<html lang="en">' >> templates/vnc_viewer.html && \
    echo '<head>' >> templates/vnc_viewer.html && \
    echo '    <meta charset="UTF-8">' >> templates/vnc_viewer.html && \
    echo '    <meta name="viewport" content="width=device-width, initial-scale=1.0">' >> templates/vnc_viewer.html && \
    echo '    <title>VNC Viewer</title>' >> templates/vnc_viewer.html && \
    echo '    <script src="https://cdnjs.cloudflare.com/ajax/libs/noVNC/1.2.0/vnc.min.js"></script>' >> templates/vnc_viewer.html && \
    echo '</head>' >> templates/vnc_viewer.html && \
    echo '<body>' >> templates/vnc_viewer.html && \
    echo '    <h1>VNC Viewer</h1>' >> templates/vnc_viewer.html && \
    echo '    <div id="noVNC_container" style="height: 80vh;"></div>' >> templates/vnc_viewer.html && \
    echo '    <script>' >> templates/vnc_viewer.html && \
    echo '        const rfb = new RFB(document.getElementById("noVNC_container"), "ws://localhost:5901");' >> templates/vnc_viewer.html && \
    echo '        rfb.viewOnly = false;' >> templates/vnc_viewer.html && \
    echo '        rfb.scaleViewport = true;' >> templates/vnc_viewer.html && \
    echo '    </script>' >> templates/vnc_viewer.html && \
    echo '</body>' >> templates/vnc_viewer.html && \
    echo '</html>' >> templates/vnc_viewer.html

# Expose the ports the app and VNC server run on
EXPOSE 5000 5901

# Run the Flask application
CMD ["python3", "app.py"]

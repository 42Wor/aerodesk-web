from flask import Flask, render_template, send_from_directory

app = Flask(__name__, template_folder='../templates', static_folder='../static')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/install.sh')
def install_sh():
    return send_from_directory('../static', 'install.sh', mimetype='text/plain')

@app.route('/install.ps1')
def install_ps1():
    return send_from_directory('../static', 'install.ps1', mimetype='text/plain')

@app.route('/wallpapers.json')
def wallpapers_json():
    return send_from_directory('../static', 'wallpapers.json', mimetype='application/json')

@app.route('/previews/<path:filename>')
def serve_previews(filename):
    return send_from_directory('../static/previews', filename)

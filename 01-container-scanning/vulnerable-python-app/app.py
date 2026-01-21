from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return 'Vulnerable Python App - SCA Testing Lab'

@app.route('/health')
def health():
    return jsonify({
        'status': 'running',
        'message': 'This app has intentionally outdated dependencies for SCA scanning demonstration'
    })

if __name__ == '__main__':
    print('WARNING: This app contains known vulnerabilities for testing purposes only')
    app.run(host='0.0.0.0', port=5000, debug=True)

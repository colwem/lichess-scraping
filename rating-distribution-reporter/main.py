from flask import Flask, jsonify, render_template
from firestore import get_db
from itertools import groupby
import json
app = Flask(__name__)

db = get_db()

@app.route('/')
def home():

    distributions = db.collection(u'distributions')
    data = [d.to_dict() for d in distributions.stream()]
    for d in data:
        d['date'] = d['date'].strftime('%d%m%y%H')

    return render_template('home.html', data=data)


@app.route("/download")
def download_all():
    distributions = db.collection(u'distributions')
    lst = [d.to_dict() for d in distributions.stream()]
    return jsonify(lst)

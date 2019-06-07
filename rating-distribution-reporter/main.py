from flask import Flask, jsonify, render_template
from firestore import get_db
from itertools import groupby
import re
import json
app = Flask(__name__)

db = get_db()

perf_types = [
        'bullet',
        'blitz',
        'rapid',
        'classical',
        'ultraBullet',
        'crazyhouse',
        'chess960',
        'atomic',
        'kingOfTheHill',
        'horde',
        'racingKings',
        'threeCheck',
        'antichess', ]

@app.route('/')
def home():

    distributions = db.collection(u'distributions')
    data = [d.to_dict() for d in distributions.stream()]
    [d.pop('distribution') for d in data]
    for d in data:
        d['date'] = d['date'].strftime('%d%m%y%H')
    return render_template('home.html', data=data, perf_types=perf_types)


@app.route("/download")
def download_all():
    distributions = db.collection(u'distributions')
    lst = [d.to_dict() for d in distributions.stream()]
    return jsonify(lst)

@app.template_filter()
def snake_to_title(s):
    s = s[0].upper() + s[1:]
    return ' '.join(re.findall('[A-Z][^A-Z]*', s))

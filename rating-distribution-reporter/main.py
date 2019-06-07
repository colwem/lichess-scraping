from flask import Flask, jsonify, render_template, abort
from firestore import get_db
from itertools import groupby
import os
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

date_format = '%d%m%y%H'

# routes
@app.route('/')
def home():
    return render_template('home.html', perf_types=perf_types)

@app.route('/distributions')
def distributions():
    return render_template('distributions.html', perf_types=perf_types)

# api routes
@app.route('/api/percentiles/<perf_type>')
def percentiles(perf_type):
    if perf_type not in perf_types:
        abort(404)
    distributions = db.collection(u'distributions')
    docs = list(distributions.where('perf_type', '==', perf_type).stream())
    percentiles = list(docs[0].get('percentiles').keys())
    percentiles = sorted(percentiles, key=int)
    lines = []
    for percentile in percentiles:
        lines.append({
            'percentile': percentile,
            'line': [{
                'date': d.get('date').strftime(date_format),
                'rating': d.get('percentiles')[percentile] }
                for d in docs] })
    return jsonify(lines)


@app.route('/api/distributions/<perf_type>')
def distributions_api(perf_type):
    if perf_type not in perf_types:
        abort(404)
    distributions = db.collection(u'distributions')
    docs = list(distributions.where('perf_type', '==', perf_type).stream())
    return jsonify([{
        'distribution': d.get('distribution'),
        'date': d.get('date').strftime(date_format)}
        for d in docs])

@app.route("/api/download")
def download_all():
    distributions = db.collection(u'distributions')
    lst = [d.to_dict() for d in distributions.stream()]
    return jsonify(lst)




# Filters

@app.template_filter()
def snake_to_title(s):
    s = s[0].upper() + s[1:]
    return ' '.join(re.findall('[A-Z][^A-Z]*', s))


@app.template_filter()
def autoversion(filename):
  # determining fullpath might be project specific
  fullpath = filename[1:]
  print(fullpath)
  try:
      timestamp = str(os.path.getmtime(fullpath))
  except OSError:
      print("errored")
      return filename
  newfilename = "{0}?v={1}".format(filename, timestamp)
  print(newfilename)
  return newfilename

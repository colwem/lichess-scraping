from bs4 import BeautifulSoup
import backoff
import time
import datetime
import requests
import re
import json
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore


db = firestore.client()
def parse_distribution(txt):
    soup = BeautifulSoup(txt, 'html.parser')
    scripts = soup.find_all("script")
    texts = [script.string for script in scripts]
    distribution = next(text for text in texts
            if text and 'lichess.ratingDistributionChart' in text)
    distribution = re.search(r'\[[0-9, ]+\]', distribution).group()
    return json.loads(distribution)


@backoff.on_exception(backoff.expo,
        requests.exceptions.RequestException,
        max_time=300)
def get_url(url):
    time.sleep(1)
    return requests.get(url)

def get_db():
    cred = credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred, {
        'projectId': 'lichess-scraping',
    })
    return firestore.client()

url_tmpl = 'https://lichess.org/stat/rating/distribution/{perf_type}'
perf_types = [
        'bullet',
        'blitz',
        'rapid',
        'clasical',
        'ultrabullet',
        'crazyhouse',
        'chess960',
        'kingOfTheHill',
        'threeCheck',
        'antichess',
        'atomic',
        'horde',
        'racingKings']

def scrape_rating_distributions(data, context):
    # Use the application default credentials
    db = get_db()
    dists_ref = db.collection(u'distributions')
    for perf_type in perf_types:

        page = get_url(url_tmpl.format(perf_type=perf_type))
        distribution = parse_distribution(page)
        dists_ref.add({
            u'distribution': distribution,
            u'date': datetime.datetime.now(),
            u'perf_type': perf_type
        })


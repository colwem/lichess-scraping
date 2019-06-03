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


def parse_distribution(source):
    soup = BeautifulSoup(source, 'html.parser')
    scripts = soup.find_all("script")
    texts = [script.string for script in scripts]
    distribution = next(text for text in texts
            if text and 'lichess.ratingDistributionChart' in text)
    distribution = re.search(r'\[[0-9, ]+\]', distribution).group()
    return json.loads(distribution)


@backoff.on_exception(backoff.expo,
        requests.exceptions.RequestException,
        max_time=300)
def get(url):
    time.sleep(2)
    return requests.get(url)

def get_db():
    try:
        app = firebase_admin.get_app()
    except ValueError as e:
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
        'classical',
        'ultraBullet',
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
        response = get(url_tmpl.format(perf_type=perf_type))
        try:
            distribution = parse_distribution(response.text)
            date = datetime.datetime.now()
            id = perf_type + date.strftime('%d%m%y%H')
            dists_ref.document(id).set({
                u'distribution': distribution,
                u'date': date,
                u'perf_type': perf_type
            })
        except Exception as e:
            print(perf_type)
            print(response.status)
            print(response.text)
            raise e

if __name__ == "__main__":
    scrape_rating_distributions('blah', 'blam')


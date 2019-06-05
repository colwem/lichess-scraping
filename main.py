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

def apply_with_sleep(f, lst, slp):
    if len(lst) == 0:
        yield None
    elif len(lst) == 1:
        yield f(lst[0])
    else:
        for l in lst[:-1]:
            yield f(l)
            time.sleep(slp)
        yield f(lst[-1])

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
    return requests.get(url)


@backoff.on_exception(backoff.expo,
        Exception,
        max_time=300)
def get_db():
    try:
        app = firebase_admin.get_app()
    except ValueError as e:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred, {
            'projectId': 'lichess-scraping',
        })
    return firestore.client()

@backoff.on_exception(backoff.expo,
        Exception,
        max_time=300)
def write_to_db_with_backoff(db, collection, id, data):
    dists_ref = db.collection(collection)
    dists_ref.document(id).set(data)

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

def simple_generator(lst):
    for l in lst:
        yield l
    return None

def scrape_rating_distributions(data, context):
    # Use the application default credentials
    db = get_db()
    urls = [url_tmpl.format(perf_type=perf_type) for perf_type in perf_types]
    for response, perf_type in zip(apply_with_sleep(get, urls, 1), perf_types):
        try:
            distribution = parse_distribution(response.text)
        except Exception as e:
            print(perf_type)
            print(response.status_code)
            print(response.text)
            raise e

        date = datetime.datetime.now()
        id = perf_type + date.strftime('%d%m%y%H')
        write_to_db_with_backoff(db, u'distributions', id, {
            u'distribution': distribution,
            u'date': date,
            u'perf_type': perf_type})

if __name__ == "__main__":
    scrape_rating_distributions('blah', 'blam')


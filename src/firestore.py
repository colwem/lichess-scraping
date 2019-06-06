import backoff
import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

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

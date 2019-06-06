To deploy

```
gcloud functions deploy scrape_rating_distributions \
  --project=lichess-scraping \
  --trigger-topic scrape-distributions \
  --runtime=python37;
```

To run locally

```
export GOOGLE_APPLICATION_CREDENTIALS='<path-to-creds-file>'
python main.py
```

Guy with rating stats @robinson_dudeski

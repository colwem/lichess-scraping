from firestore import get_db


def add_percentiles(data, context):
    db = get_db()
    path_parts = context.resource.split('/documents/')[1].split('/')
    collection_path = path_parts[0]
    document_path = '/'.join(path_parts[1:])
    doc = db.collection(collection_path).document(document_path)

    distribution = (
            data["value"]["fields"]["distribution"]['arrayValue']['values'])
    distribution = [int(d['integerValue']) for d in distribution]

    percentiles = [0.05, 0.25, 0.5, 0.75, 0.95, 0.99]

    bucket_width = 25
    rating_range_bottom_edges = range(800, 2801, bucket_width)

    main(doc, distribution, rating_range_bottom_edges, percentiles)

def main(doc_ref, distribution, rating_range_bottom_edges, percentiles):
    percentile_function = get_percentile_function(
            rating_range_bottom_edges, distribution)

    percentile_ratings = [percentile_function(p) for p in percentiles]

    field_names = [str(int(p * 100)) for p in percentiles]
    d = {str(p): r for p, r in zip(field_names, percentile_ratings)}
    doc_ref.update({'percentiles': d})

def first_index_above_n(n, arr):
    for i, c in enumerate(arr):
        if c > n:
            return i
    return None

def cumulative_distribution(dist):
    cum = []
    count = 0
    for n in dist:
        count += n
        cum.append(count)
    return cum

def get_percentile_function(x, y):
    cum_y = cumulative_distribution(y)
    total = cum_y[-1]
    def fun(p):
        n = total * p
        i = first_index_above_n(n, cum_y)
        percentage_off = (n - cum_y[i-1]) / y[i]
        bucket_width = x[i+1] - x[i]
        # this isn't the best method
        # should calculate based on percentage of
        # mass under interpolated line
        return x[i] + percentage_off * bucket_width
    return fun


if __name__ == "__main__":
    db = get_db()
    distributions = db.collection('distributions')
    for doc_ref in distributions.list_documents():
        distribution = doc_ref.get().get('distribution')

        percentiles = [0.05, 0.25, 0.5, 0.75, 0.95, 0.99]

        bucket_width = 25
        rating_range_bottom_edges = range(800, 2801, bucket_width)

        main(doc_ref, distribution, rating_range_bottom_edges, percentiles)

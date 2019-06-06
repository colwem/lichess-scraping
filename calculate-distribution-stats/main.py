from firestore import get_db


def add_percentiles(data, context):
    db = get_db()
    path_parts = context.resource.split('/documents/')[1].split('/')
    collection_path = path_parts[0]
    document_path = '/'.join(path_parts[1:])

    doc = db.collection(collection_path).document(document_path)
    distribution = data["value"]["fields"]["distribution"]['arrayValues']

    distribution = [d['integerValue'] for d in distribution]
    ratings = range(812.5, 2813.5, 25)
    percentiles = [0.05, 0.25, 0.5, 0.75, 0.95]
    percentile_ratings = get_percentile_ratings(percentiles, distribution)
    d = {p: r for p, r in zip(percentiles, percentile_ratings)}
    doc.set(d)

def first_index_above_n(n, arr):
    for i, c in enumerate(arr):
        if c > n:
            return i
    return None

def get_percentile_ratings(percentiles, dist):
    # create the cumulative distribution
    cumulative = []
    count = 0
    for n in dist:
        count += n
        cumulative.append(count)
    total = cumulative[-1]

    # create the histogram buckets that were used
    # each value is the bottom edge of the bucket
    bucket_widths = 25
    rating_range_bottom_edges = range(800, 2801, bucket_widths)

    # calculate the rating threshold for every percentile requested
    percentile_ns = [total * p for p in percentiles]
    percentile_ratings = []
    for n in percentile_ns:
        i = first_index_above_n(n, cumulative)
        miss_distance = n - cumulative[i-1]
        bucket_count = dist[i]
        percentage_off = miss_distance / bucket_count
        # this isn't the best method
        # should calculate based on percentage of
        # mass under interpolated line
        percentile_rating = (
                rating_range_bottom_edges[i]
                + percentage_off * bucket_widths)

        percentile_ratings.append(percentile_rating)

    return percentile_ratings

if __name__ == "__main__":
    arr = [0] * 81
    arr[0] =1
    arr[1] =1
    arr[2] =1
    arr[3] =1
    arr = [3,0,3,3,0,3,2,5,11,17,14,23,28,37,52,67,70,73,78,92,96,120,102,125,
            86,135,106,92,103,86,100,86,81,100,82,71,90,65,61,66,56,68,44,35,
            46,32,43,39,48,26,21,14,33,18,14,11,11,6,4,6,1,2,0,0,1,0,1,0,1,0,
            0,0,0,0,0,0,0,0,0,0,0]
    print(get_percentile_ratings([0.5], arr))



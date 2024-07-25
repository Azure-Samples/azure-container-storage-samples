#!/usr/bin/env python

from elasticsearch import Elasticsearch
import json
import random
from datetime import datetime
import lorem
import logging
import time

# Configure logging to write to stdout and stderr
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logging.getLogger('elastic_transport.transport').setLevel(logging.WARNING)

# Elasticsearch server settings
es = Elasticsearch("http://elasticsearch-v1.elasticsearch.svc.cluster.local:9200")

# Validate Elasticsearch connection
if not es.ping():
    logging.error('Elasticsearch connection failed')
    exit(1)

# Index name
index_name = "my_app_logs"

# Number of dummy logs to generate
num_logs = 30000000

# Validate Elasticsearch index settings
index_info = es.indices.get(index=index_name)
if not index_info:
    logging.error(f'Failed to get information about the index "{index_name}"')
    exit(1)

init_count = es.count(index=index_name)['count']
logging.info(f"Index '{index_name}' initially contains {init_count} logs")
final_count = init_count + (num_logs/2)

try:
    # Generate and ingest dummy logs
    actions_list = []
    for i in range(1, num_logs + 1):
        log_entry = {
            "@timestamp": datetime.now().isoformat(),
            "message": lorem.sentence(),
            "log_level": random.choice(["INFO", "ERROR", "DEBUG", "WARNING"]),
            "log_source": random.choice(["AppServer", "WebServer", "Database", "Worker"]),
        }
        actions_list.append({"index": {}, "body": json.dumps(log_entry)})
        
        if i % 10000 == 0:
            # Ingest the log entry into the index in bulk
            es.bulk(operations=actions_list, index=index_name)
            actions_list = []
            logging.info(f"Ingested {i} logs")

    logging.info(f"Successfully ingested {num_logs} sample logs into the '{index_name}' index.")
except Exception as e:
    logging.error(f'Error during data ingestion: {e}')
    exit(1)

count = es.count(index=index_name)['count']
while count < final_count:
    logging.info(f"Index '{index_name}' contains {count} logs")
    count = es.count(index=index_name)['count']
    time.sleep(2)
    

# Log a success message
logging.info('Script completed successfully')
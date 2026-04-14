#!/bin/bash

MAX_RETRIES=3
RETRY_DELAY=10
HEALTH_CHECK_RETRIES=12
HEALTH_CHECK_DELAY=5

log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

log_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}

retry_operation() {
    local operation_name="$1"
    local command="$2"
    local retry_count=0

    log_info "Starting ${operation_name}"

    while [ $retry_count -lt $MAX_RETRIES ]; do
        if eval "$command"; then
            log_success "${operation_name} succeeded"
            return 0
        fi

        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            log_warn "${operation_name} failed, retrying in ${RETRY_DELAY}s... (${retry_count}/${MAX_RETRIES})"
            sleep $RETRY_DELAY
        else
            log_error "${operation_name} failed after ${MAX_RETRIES} attempts"
            return 1
        fi
    done
}

check_cluster_health() {
    local retry_count=0

    log_info "Checking Elasticsearch cluster health..."

    while [ $retry_count -lt $HEALTH_CHECK_RETRIES ]; do
        local health_status
        health_status=$(curl -s "http://elasticsearch:9200/_cluster/health" 2>/dev/null)

        if [ $? -eq 0 ] && echo "$health_status" | grep -q '"status":"green"\|"status":"yellow"'; then
            local status
            status=$(echo "$health_status" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            log_success "Elasticsearch cluster status: ${status}"
            return 0
        fi

        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $HEALTH_CHECK_RETRIES ]; then
            log_warn "Cluster not ready yet, retrying in ${HEALTH_CHECK_DELAY}s... (${retry_count}/${HEALTH_CHECK_RETRIES})"
            sleep $HEALTH_CHECK_DELAY
        else
            log_error "Elasticsearch cluster health check failed after ${HEALTH_CHECK_RETRIES} attempts"
            return 1
        fi
    done
}

log_info "Waiting for Elasticsearch to become available..."
until curl -s http://elasticsearch:9200/_cluster/health > /dev/null 2>&1; do
    log_info "Waiting for Elasticsearch to become available..."
    sleep 5
done

log_success "Elasticsearch is reachable"

if ! check_cluster_health; then
    log_error "Elasticsearch cluster health check failed, aborting initialization"
    exit 1
fi

log_info "Creating ingest pipeline and index..."

pipeline_command='curl -s -f -X PUT "http://elasticsearch:9200/_ingest/pipeline/parsing_loongsuite_traces" \
  -H "Content-Type: application/json" \
  -d '"'"'{
    "processors": [
      {
        "json": {
          "field": "contents.attribute",
          "target_field": "attributes"
        }
      },
      {
        "json": {
          "field": "contents.resource",
          "target_field": "resources"
        }
      },
      {
        "json": {
          "field": "contents.links",
          "target_field": "spanLinks"
        }
      },
      {
        "json": {
          "field": "contents.logs",
          "target_field": "spanEvents"
        }
      },
      {
        "remove": {
          "field": [
            "contents.attribute",
            "contents.resource",
            "contents.links",
            "contents.logs"
          ]
        }
      },
      {
        "rename": {
          "field": "contents",
          "target_field": "metadata"
        }
      },
      {
        "script": {
          "source": "Map usage = new HashMap();\nlong total = 0;\nif (ctx.attributes.containsKey(\"gen_ai.usage.input_tokens\")) {\n  long input = Long.parseLong(ctx.attributes[\"gen_ai.usage.input_tokens\"]);\n  usage[\"input_tokens\"] = input;\n  total = total + input;\n}\nif (ctx.attributes.containsKey(\"gen_ai.usage.output_tokens\")) {\n  long output = Long.parseLong(ctx.attributes[\"gen_ai.usage.output_tokens\"]);\n  usage[\"output_tokens\"] = output;\n  total = total + output;\n}\nusage[\"total_tokens\"] = total;\nctx.usage = usage;"
        }
      }
    ]
  }'"'"''

if ! retry_operation "Create parsing_loongsuite_traces pipeline" "$pipeline_command"; then
    exit 1
fi

pipeline_verification_command='curl -s -f "http://elasticsearch:9200/_ingest/pipeline/parsing_loongsuite_traces" > /dev/null'
if ! retry_operation "Verify pipeline creation" "$pipeline_verification_command"; then
    exit 1
fi

index_command='curl -s -f -X PUT "http://elasticsearch:9200/loongsuite_traces" \
  -H "Content-Type: application/json" \
  -d '"'"'{
    "settings": {
      "index.default_pipeline": "parsing_loongsuite_traces"
    },
    "mappings": {
      "dynamic": "false",
      "properties": {
        "metadata": {
          "type": "object",
          "properties": {
            "duration": {
              "type": "long"
            },
            "end": {
              "type": "long"
            },
            "host": {
              "type": "keyword"
            },
            "kind": {
              "type": "text"
            },
            "name": {
              "type": "keyword"
            },
            "otlp": {
              "type": "object",
              "properties": {
                "name": {
                  "type": "keyword"
                },
                "version": {
                  "type": "version"
                }
              }
            },
            "parentSpanID": {
              "type": "text"
            },
            "service": {
              "type": "keyword"
            },
            "spanID": {
              "type": "text"
            },
            "start": {
              "type": "long"
            },
            "statusCode": {
              "type": "text"
            },
            "statusMessage": {
              "type": "keyword"
            },
            "traceID": {
              "type": "text"
            },
            "traceState": {
              "type": "keyword"
            }
          }
        },
        "tags": {
          "type": "object"
        },
        "time": {
          "type": "long"
        },
        "attributes": {
          "type": "flattened"
        },
        "resources": {
          "type": "flattened"
        },
        "spanEvents": {
          "type": "nested",
          "properties": {
            "name": {
              "type": "keyword"
            },
            "attribute": {
              "type": "flattened"
            },
            "time": {
              "type": "long"
            }
          }
        },
        "spanLinks": {
          "type": "nested",
          "properties": {
            "spanID": {
              "type": "text"
            },
            "traceID": {
              "type": "text"
            },
            "attribute": {
              "type": "flattened"
            }
          }
        },
        "usage": {
          "type": "object",
          "properties": {
            "input_tokens": {
              "type": "long"
            },
            "output_tokens": {
              "type": "long"
            },
            "total_tokens": {
              "type": "long"
            }
          }
        }
      }
    }
  }'"'"''

if ! retry_operation "Create loongsuite_traces index" "$index_command"; then
    exit 1
fi

log_info "Waiting for index creation to settle..."
sleep 5

verification_command='curl -s -f "http://elasticsearch:9200/loongsuite_traces/_mapping" > /dev/null'
if ! retry_operation "Verify index creation" "$verification_command"; then
    exit 1
fi

index_status_command='curl -s -f "http://elasticsearch:9200/_cat/indices/loongsuite_traces?v"'
if ! retry_operation "Check index status" "$index_status_command"; then
    exit 1
fi

log_success "Index initialization completed"
log_success "Elasticsearch initialization completed"
exit 0


> TODO: in a later example

defines no fragmentation strategy (we will learn about this in futher examples) and 
* add swagger:
```yaml
springdoc:
  swagger-ui:
    path: /admin/doc/v1/swagger
    urlsPrimaryName: admin
```
=> admin API for managing
* create [LDES definition](./quick-start/definitions/occupancy.ttl)
* use admin API to upload definition to LDES server
```bash
curl -X POST "http://localhost:9003/ldes/admin/api/v1/eventstreams" -H "Content-Type: text/turtle" -d "@./quick-start/definitions/occupancy.ttl"
```
=> http://localhost:9003/ldes/occupancy
* use retention






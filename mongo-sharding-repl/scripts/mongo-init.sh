#!/bin/bash
set -e

# INIT CONFIG SERVER RS
echo "Initializing Config Server Replica Set"

docker compose exec -T cfg1 mongosh --port 27017 <<'EOF'
rs.initiate({
  _id: 'config_rs',
  configsvr: true,
  members: [
    { _id: 0, host: 'cfg1:27017' },
    { _id: 1, host: 'cfg2:27017' },
    { _id: 2, host: 'cfg3:27017' }
  ]
})
EOF

sleep 3

# INIT SHARD 1 RS
echo "Initializing Shard1 Replica Set"

docker compose exec -T shard1a mongosh --port 27018 <<'EOF'
rs.initiate({
  _id: 'shard1_rs',
  members: [
    { _id: 0, host: 'shard1a:27018' },
    { _id: 1, host: 'shard1b:27018' },
    { _id: 2, host: 'shard1c:27018' }
  ]
})
EOF

sleep 3

# INIT SHARD 2 RS
echo "Initializing Shard2 Replica Set"

docker compose exec -T shard2a mongosh --port 27019 <<'EOF'
rs.initiate({
  _id: 'shard2_rs',
  members: [
    { _id: 0, host: 'shard2a:27019' },
    { _id: 1, host: 'shard2b:27019' },
    { _id: 2, host: 'shard2c:27019' }
  ]
})
EOF

sleep 3

# ADD SHARDS VIA MONGOS
echo "Adding shards to cluster"

docker compose exec -T mongos1 mongosh --port 27020 <<'EOF'
sh.addShard('shard1_rs/shard1a:27018,shard1b:27018,shard1c:27018')
sh.addShard('shard2_rs/shard2a:27019,shard2b:27019,shard2c:27019')
EOF

sleep 3

# ENABLE SHARDING
echo "Enabling sharding for database and collection"

docker compose exec -T mongos1 mongosh --port 27020 <<'EOF'
sh.enableSharding('somedb')
sh.shardCollection('somedb.helloDoc', { name: 'hashed' })
EOF

# FILL DATABASE WITH DATA
echo "Inserting test data"

docker compose exec -T mongos1 mongosh --port 27020 <<'EOF'
use somedb
for (var i = 0; i < 1000; i++) {
  db.helloDoc.insertOne({ age: i, name: 'ly' + i })
}
db.helloDoc.countDocuments()
EOF

echo "MongoDB sharded cluster initialized successfully!"

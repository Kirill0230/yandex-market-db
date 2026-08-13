kirillkhuzeev@MacBook-Pro-Kirill M3201_KhuzeevKYu % docker exec -it postgres1 patronictl -c /config/patroni.yml list
+ Cluster: postgres-cluster (7636054578915766304) -+-------------+-----+------------+-----+
| Member    | Host      | Role    | State     | TL | Receive LSN | Lag | Replay LSN | Lag |
+-----------+-----------+---------+-----------+----+-------------+-----+------------+-----+
| postgres1 | postgres1 | Leader  | running   |  2 |             |     |            |     |
| postgres2 | postgres2 | Replica | streaming |  2 |   0/304FC38 |   0 |  0/304FC38 |   0 |
+-----------+-----------+---------+-----------+----+-------------+-----+------------+-----+

После команды docker stop postgres1

kirillkhuzeev@MacBook-Pro-Kirill M3201_KhuzeevKYu % docker exec -it postgres2 patronictl -c /config/patroni.yml list
+ Cluster: postgres-cluster (7636054578915766304) ------------+-----+------------+-----+
| Member    | Host      | Role   | State   | TL | Receive LSN | Lag | Replay LSN | Lag |
+-----------+-----------+--------+---------+----+-------------+-----+------------+-----+
| postgres2 | postgres2 | Leader | running |  3 |             |     |            |     |
+-----------+-----------+--------+---------+----+-------------+-----+------------+-----+

kirillkhuzeev@MacBook-Pro-Kirill M3201_KhuzeevKYu % docker exec -e PGPASSWORD=postgres postgres2 psql \
  -h haproxy -p 5000 -U postgres -d postgres \
  -c "SELECT inet_server_addr(), pg_is_in_recovery();"
 inet_server_addr | pg_is_in_recovery 
------------------+-------------------
 172.21.0.4       | f
(1 row)
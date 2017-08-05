#    AsyncMysql - Asynchronous MySQL connector written in pure Nim
#        (c) Copyright 2017 Wang Tong
#
#    See the file "LICENSE", included in this distribution, for
#    details about the copyright.

import unittest, asyncmysql, util, asyncdispatch, asyncnet, net

const 
  MysqlHost = "127.0.0.1"
  MysqlPort = Port(3306)
  MysqlUser = "mysql"
  MysqlPassword = "123456"

suite "AsyncMysqlConnection":
  test "query multiply":
    proc sendComQuery() {.async.} =
      var conn = await open(AF_INET, MysqlPort, MysqlHost, MysqlUser, MysqlPassword, "mysql")
      var stream = await execQuery(conn, sql("""
start transaction;
select host, user from user where user = ?;
select user from user;
commit;
""", "root"))

      let packet0 = await read(stream)
      echo "  >>> strart transaction;"
      echo "  ", packet0
      check stream.finished == false
      check packet0.kind == rpkOk
      check packet0.hasMoreResults == true

      let packet1 = await read(stream)
      echo "  >>> select host, user from user where user = ?;"
      echo "  ", packet1
      check stream.finished == false
      check packet1.kind == rpkResultSet
      check packet1.hasMoreResults == true

      let packet2 = await read(stream)
      echo "  >>> select user from user;"
      echo "  ", packet2
      check stream.finished == false
      check packet2.kind == rpkResultSet
      check packet2.hasMoreResults == true

      let packet3 = await read(stream)
      echo "  >>> commit;"
      echo "  ", packet3
      check stream.finished == true
      check packet3.kind == rpkOk
      check packet3.hasMoreResults == false

      close(conn)
    waitFor1 sendComQuery() 

  test "query multiply with bad results":
    proc sendComQuery() {.async.} =
      var conn = await open(AF_INET, MysqlPort, MysqlHost, MysqlUser, MysqlPassword, "mysql")
      var stream = await execQuery(conn, sql("""
select 100;
select var;
select 10;
""", "root"))
      
      let packet0 = await read(stream)
      echo "  >>> select 100;"
      echo "  ", packet0
      check stream.finished == false
      check packet0.kind == rpkResultSet
      check packet0.hasMoreResults == true

      let packet1 = await read(stream)
      echo "  >>> select var;"
      echo "  ", packet1
      check stream.finished == true
      check packet1.kind == rpkError
      check packet1.hasMoreResults == false

      close(conn)
    waitFor1 sendComQuery() 

  test "query singly":
    proc sendComQuery() {.async.} =
      var conn = await open(AF_INET, MysqlPort, MysqlHost, MysqlUser, MysqlPassword, "mysql")
      let packet = await execQueryOne(conn, sql("select 100"))
      echo "  >>> select 100;"
      echo "  ", packet
      check packet.kind == rpkResultSet
      check packet.hasMoreResults == false
      close(conn)
    waitFor1 sendComQuery() 

  test "ping":
    proc sendComQuery() {.async.} =
      var conn = await open(AF_INET, MysqlPort, MysqlHost, MysqlUser, MysqlPassword, "mysql")
      let packet = await execPing(conn)
      echo "  >>> ping;"
      echo "  ", packet
      check packet.kind == rpkOk
      check packet.hasMoreResults == false
      close(conn)
    waitFor1 sendComQuery()  

  test "use <database>":
    proc sendComQuery() {.async.} =
      var conn = await open(AF_INET, MysqlPort, MysqlHost, MysqlUser, MysqlPassword, "mysql")

      let packet0 = await execQueryOne(conn, sql"use test")
      echo "  >>> use test;"
      echo "  ", packet0
      check packet0.kind == rpkOk
      check packet0.hasMoreResults == false

      let packet1 = await execQueryOne(conn, sql("select * from user;"))
      echo "  >>> select * from user;"
      echo "  ", packet1
      check packet1.kind == rpkError
      check packet0.hasMoreResults == false

      close(conn)
    waitFor1 sendComQuery()  

  test "show full fields from <table>":
    proc sendComQuery() {.async.} =
      var conn = await open(AF_INET, MysqlPort, MysqlHost, MysqlUser, MysqlPassword, "mysql")
      let packet0 = await execQueryOne(conn, sql"show full fields from user;")
      echo "  >>> show full fields from user;"
      echo "  ... ", packet0.fields[0], " ..."
      check packet0.kind == rpkResultSet
      check packet0.hasMoreResults == false
      close(conn)
    waitFor1 sendComQuery()   

  test "change user":
    proc sendComQuery() {.async.} =
      var conn = await open(AF_INET, MysqlPort, MysqlHost, MysqlUser, MysqlPassword, "mysql")
      let packet0 = await execChangeUser(conn, "mysql2", MysqlPassword, "mysql", DefaultClientCharset)
      echo "  >>> change user;"
      echo "  ", packet0
      check packet0.kind == rpkOk
      check packet0.hasMoreResults == false
      close(conn)
    waitFor1 sendComQuery()   

  test "quit":
    proc sendComQuery() {.async.} =
      var conn = await open(AF_INET, MysqlPort, MysqlHost, MysqlUser, MysqlPassword, "mysql")
      await execQuit(conn)
      close(conn)
    waitFor1 sendComQuery()   


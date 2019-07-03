import MySQLdb 

db = MySQLdb.connect(host="hades",  user="django", passwd="kkER%%nup",  db="test")
cur = db.cursor()
sql = 'select * from Persons'
cur.execute(sql)
res= cur.fetchall()
print ("DB init state")
print ("entries: ",len(res))

for i in range (4,20):
    sql = 'insert into Persons values ('+str(i)+', "tester'+str(i)+'", "test'+str(i)+'", "some place'+str(i)+'", "city'+str(i)+'");'
    cur.execute(sql) 
    db.commit()

sql = 'select * from Persons'                                                                                                                                                                                      
cur.execute(sql)                                                                                                                                                                                                   
res= cur.fetchall()      
print ("DB added entries state")
print ("entries: ",len(res))

print ("deleting...")
for i in range (4,20):
    sql='delete from `Persons` where PersonID="'+str(i)+'";' 
    e=cur.execute(sql)
    print(e)
    db.commit()
    sql = 'select * from Persons'
    cur.execute(sql)
    res= cur.fetchall()
    print ("entries: ",len(res))

db.close()

print ("close and reopen DB")
db = MySQLdb.connect(host="hades",  user="django", passwd="kkER%%nup",  db="test")
cur = db.cursor()
sql = 'select * from Persons'
cur.execute(sql)
res= cur.fetchall()
print ("entries: ",len(res))

db.close()

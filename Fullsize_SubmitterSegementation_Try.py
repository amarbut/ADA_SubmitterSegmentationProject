# -*- coding: utf-8 -*-
"""
Created on Mon Nov  5 12:48:26 2018

@author: Anna
"""
import psycopg2
import pandas as pd
import pickle
import os
from sklearn.decomposition import PCA, TruncatedSVD
#%%
#collect all submitter/submission combinations per product createdate
conn=psycopg2.connect(dbname= '', host='', 
                     port= '', user= '', password= '')

sql = '''select distinct p.productid, p.description, p.name, u.userid
         from submittable_db.product p
         left join submittable_db.publisher pub on p.publisherid = pub.publisherid
         left join submittable_db.submission s on p.productid = s.productid
         left join submittable_db.smmuser u on s.userid = u.userid
         where pub.accounttypeid not in (11, 16, 64)'''

years = list(range(2010, 2019))

#collect submissions for forms created in each year (to break up huge dataset)
for year in years:
    submissions = pd.read_sql_query(sql+"and extract(year from p.createdate) = " + str(year),
                                     con= conn)
    picklepath = "submissions"+str(year)+".pkl"
    pickle.dump(submissions, open(picklepath, "wb"))
#%%
#collect userids with less than 3 submissions

sql = '''select * from(
             select u.userid, count(s.submissionid) as num_sub
             from submittable_db.smmuser u
             left join submittable_db.submission s on u.userid = s.userid
             group by 1)
         where num_sub < 3'''

low_subs = pd.read_sql_query(sql, con = conn)
pickle.dump(low_subs, open("low_subs.pkl", "wb"))
#%%
#collect forms with less than 3 submissions

sql = '''select *
            from (select p.productid, count(s.submissionid) as num_sub
                  from submittable_db.product p
                  left join submittable_db.submission s on p.productid = s.productid
                  group by 1)
            where num_sub < 3'''

low_forms = pd.read_sql_query(sql, con = conn)
pickle.dump(low_forms, open("low_forms.pkl", "wb"))
#%%
#iterate through submission files and remove users who have less than 3 submissions

for file in os.listdir("submissions"):
    with open ("submissions/"+file, "rb") as fp:
        submissions = pickle.load(fp)
        submissions = submissions[~submissions['userid'].isin(low_subs['userid'])]
    with open ("clean"+file, "wb") as fp:
        pickle.dump(submissions, fp)

#%%
#iterate through submission files and remove forms that have less than 3 submissions
        
for file in os.listdir("sans_submitters"):
    with open ("sans_submitters/"+file, "rb") as fp:
        submissions = pickle.load(fp)
        submissions = submissions[~submissions['productid'].isin(low_forms['productid'])]
    with open ("cleaner"+file, "wb") as fp:
        pickle.dump(submissions, fp)
        
#%%
#iterate through files, create dictionary for form descriptions, and save files without this text

for file in os.listdir("sans_forms"):
    descDict = {}
    with open ("sans_forms/"+file, "rb") as fp:
        submissions = pickle.load(fp)
        for i in submissions['productid'].unique():
            descDict[i] = [{'description': submissions['description'][j],
                              'name': submissions['name'][j]} for j in submissions[submissions['productid']==i].index]
    submissions = submissions[['productid', 'userid']]
    with open("cleanest"+file[12:], "wb") as fp:
        pickle.dump(submissions, fp)
    with open("descDict"+file[-8:] ,"wb") as fp:
        pickle.dump(descDict, fp)

#%%
#combine files from all years and convert to sparse pandas df 
files = []
for idx, file in enumerate(os.listdir("cleaned")):
    with open("cleaned/"+file, "rb") as f:
        files.append(pickle.load(f))

combined = pd.concat(files, ignore_index = True)

#create dummy variables
sparsedf = pd.get_dummies(combined, sparse = True)
#%%
#matrix too big to run PCA -- memory error occurs with any number of components  
pca = PCA(n_components  = 1000)
pca.fit(sparsedf)
#also tried IncrementalPCA with batches from 5-10 columns
#also tried truncatedSVD

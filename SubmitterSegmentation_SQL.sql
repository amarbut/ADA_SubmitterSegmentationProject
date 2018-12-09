--collect a list of user/form pairs for the 5000 top-submitting users and the 5000 top-receiving forms
with users as (
  select userid, count(submissionid) as num_subs
  from submittable_db.submission
  group by userid
  order by num_subs desc
  limit 5000),
forms as (
  select s.productid, count(s.submissionid) as num_subs
  from submittable_db.submission s
  join submittable_db.product p on s.productid = p.productid
  join submittable_db.publisher pub on p.publisherid = pub.publisherid
  where pub.accounttypeid not in (11, 16, 64)
  group by s.productid
  order by num_subs desc
  limit 5000)
select s.userid, s.productid
from submittable_db.submission s
right join users u on s.userid = u.userid
right join forms f on s.productid = f.productid

--collect the form descriptions for the 5000 top-receiving forms
with forms as (
  select s.productid, count(s.submissionid) as num_subs
  from submittable_db.submission s
  join submittable_db.product p on s.productid = p.productid
  join submittable_db.publisher pub on p.publisherid = pub.publisherid
  where pub.accounttypeid not in (11, 16, 64)
  group by s.productid
  order by num_subs desc
  limit 5000)
select p.productid, p.description
from submittable_db.product p
right join forms f on p.productid = f.productid

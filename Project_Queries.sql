-- use ig_clone

-- Q2 What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?
With CommentsCTE as
(
select u.id as UserID,count(c.id) as TotalComments
from comments c
join users u on u.id=c.user_id
group by u.id
order by u.id
),
LikesCTE as
(
select u.id as UserID,count(*) as Totallikes
from likes l
join users u on u.id=l.user_id
group by u.id
order by u.id
),
PostCTE as
(
select u.id as UserID,count(*) as TotalPosts
from photos p
join users u on u.id=p.user_id
group by u.id
order by u.id
)
select 
	u.id as UserID,
    TotalComments,
    TotalLikes,
    TotalPosts
from users u
join CommentsCTE c on u.id=c.UserID
join LikesCTE lc on u.id=lc.UserID
join PostCTE pc on u.id=pc.UserID ;

-- Q3 Calculate the average number of tags per post (photo_tags and photos tables).

select p.id as PostId,avg(pt.tag_id) as AvgPerPost
from photos p 
join photo_tags pt on p.id=pt.photo_id
group by p.id
order by p.id ;

-- Q4 Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.
with photoengagementCTE as 
(
    select
        p.id as photo_id,
        p.user_id,
        count(distinct l.user_id) as like_count,
        count(distinct c.id) as comment_count
    from photos p
	left join likes l on p.id = l.photo_id
	left join comments c on p.id = c.photo_id
    group by p.id
),
usersinvolveCTE as 
(
    select
        pe.user_id,
        sum(pe.like_count) as total_likes,
        sum(pe.comment_count) as total_comments,
        sum(pe.like_count + pe.comment_count) as total_engagement
    from photoengagementCTE pe
    group by pe.user_id
)
select
    ue.user_id,
    u.username,
    ue.total_likes,
    ue.total_comments,
    ue.total_engagement,
    rank() over (order by ue.total_engagement desc) as ranks
from usersinvolveCTE ue
join users u on ue.user_id = u.id
order by ue.total_engagement desc;

-- Q5 Which users have the highest number of followers and followings?
WITH followers_count AS (
    SELECT follower_id,COUNT(follower_id) AS num_followers
    FROM follows
    group by follower_id
),
followings_count AS (
    SELECT followee_id,COUNT(followee_id) AS num_followings
    FROM follows
    group by followee_id
)
SELECT 
	u.username,
    u.id,
	MAX(f.num_followers) AS max_followers,
	MAX(f1.num_followings) AS max_followings
FROM users u
left JOIN followers_count f ON u.id = f.follower_id
left JOIN followings_count f1 ON u.id = f1.followee_id
GROUP BY u.username,u.id
order by u.id ;

-- Q6 Calculate the average engagement rate (likes, comments) per post for each user.
with photoengagementCTE as 
(
    select
        p.id as photo_id,
        p.user_id,
        count(distinct l.user_id) as like_count,
        count(distinct c.id) as comment_count,
        count(distinct l.user_id) + COUNT(distinct c.id) as total_engagement
    from photos p
	left join likes l on p.id = l.photo_id
	left join comments c on p.id = c.photo_id
    group by p.id
),
involveduserCTE as 
(
    select
        pe.user_id,
        sum(pe.total_engagement) as total_engagement,
        count(pe.photo_id) as post_count
    from photoengagementCTE pe
    group by pe.user_id
)
select
    ue.user_id,
    u.username,
    ue.total_engagement,
    ue.post_count,
    round((ue.total_engagement / ue.post_count),2) as average_engagement_per_post
from involveduserCTE ue
join users u on ue.user_id = u.id
order by ue.user_id;

-- Q7 Get the list of users who have never liked any post (users and likes tables)
select id,username
from users where id not in (select user_id from likes) ;

-- Q10 Calculate the total number of likes, comments, and photo tags for each user.
with LikesCTE as
(
SELECT 
	u.id,
	COUNt(l.photo_id) AS totallikes
FROM users u
left join photos p on p.user_id=u.id
left JOIN likes l ON l.photo_id=p.id
GROUP BY u.id
),
CommentCTE as
(
SELECT 
 	u.id,
	COUNt(c.id) AS totalcomments
FROM users u
left join photos p on u.id=p.user_id
left JOIN comments c ON c.photo_id=p.id
GROUP BY u.id
),
PhototagCTE as
(
SELECT 
	u.id,
	COUNt(p1.tag_id) as totalPhototags
from users u
left join photos p on p.user_id=u.id
left join photo_tags p1 on p1.photo_id=p.id
GROUP BY u.id
)
select 
 	u.id,
    coalesce(totalcomments,0) as TotalComments,
    coalesce(totallikes,0) as TotalLikes,
    coalesce(totalPhototags,0) as TotalPhotoTags
from users u
left join CommentCTE c on u.id=c.id
left join LikesCTE l on u.id=l.id
left join PhototagCTE p on u.id=p.id
order by u.id asc ;

-- Q11 Rank users based on their total engagement (likes, comments, shares) over a month.
with LikesCount as 
(
    select 
        p.user_id,
        COUNT(l.photo_id) as total_likes
    from photos p
    left join likes l on p.id = l.photo_id
    where l.created_at >= NOW() - interval 1 month
    group by p.user_id
),
CommentsCount as 
(
    select 
        p.user_id,
        COUNT(c.photo_id) as total_comments
    from photos p
    left join comments c on p.id = c.photo_id
    where c.created_at >= NOW() - interval 1 month
    group by p.user_id
),
Engagement as 
(
    select 
        u.id as user_id,
        u.username,
        coalesce(l.total_likes, 0) + coalesce(c.total_comments, 0) as total_engagement
    from users u
    left join LikesCount l on u.id = l.user_id
    left join CommentsCount c on u.id = c.user_id
)
select 
    user_id,
    username,
    total_engagement,
    rank() over (order by total_engagement desc) as engagement_rank
from Engagement
order by engagement_rank;

-- Q12 Retrieve the hashtags that have been used in posts with the highest average number of likes. Use a CTE to calculate the average likes for each hashtag first.
with avg_likes_per_tag as 
( 
	select 
		pt.tag_id, 
		round(avg(l.user_id),2) as avg_likes 
    from photo_tags pt 
    join photos p on pt.photo_id = p.id 
    join likes l on p.id = l.photo_id 
    group by pt.tag_id 
)
select 
	t.tag_name,
	alt.avg_likes 
from avg_likes_per_tag alt 
join tags t on alt.tag_id = t.id 
order by alt.avg_likes desc;

-- Q13 Retrieve the users who have started following someone after being followed by that person
select 
	distinct u1.username 
from users u1 
join follows f1 on u1.id = f1.follower_id 
join follows f2 on u1.id = f2.followee_id 
where f1.created_at < f2.created_at;

-- SUBJECTIVE
-- Q1 Based on user engagement and activity levels, which users would you consider the most loyal or valuable? How would you reward or incentivize these users?
with LikesGiven as 
(
    select user_id, COUNT(*) as likes_given
    from likes
    where created_at >= NOW() - interval 1 month
    group by user_id
),
LikesReceived as 
(
    select p.user_id, COUNT(*) as likes_received
    from likes l
    join photos p on l.photo_id = p.id
    where l.created_at >= NOW() - interval 1 month
    group by p.user_id
),
CommentsGiven as 
(
    select user_id, COUNT(*) as comments_given
    from comments
    where created_at >= NOW() - interval 1 month
    group by user_id
),
CommentsReceived as 
(
    select p.user_id, COUNT(*) as comments_received
    from comments c
    join photos p on c.photo_id = p.id
    where c.created_at >= NOW() - interval 1 month
    group by p.user_id
),
PhotosUploaded as 
(
    select user_id, COUNT(*) as photos_uploaded
    from photos
    where created_dat >= NOW() - interval 1 month
    group by user_id
),
Followers as 
(
    select followee_id as user_id, COUNT(*) as followers
    from follows
    group by followee_id
),
Followings as 
(
    select follower_id as user_id, COUNT(*) as followings
    from follows
    group by follower_id
),
Engagement as 
(
    select 
        u.id as user_id,
        u.username,
        coalesce(lg.likes_given, 0) + coalesce(lr.likes_received, 0) +
        coalesce(cg.comments_given, 0) + coalesce(cr.comments_received, 0) +
        coalesce(pu.photos_uploaded, 0) + coalesce(f.followers, 0) +
        coalesce(fg.followings, 0) AS total_engagement
    from 
        users u
    left join LikesGiven lg on u.id = lg.user_id
    left join LikesReceived lr on u.id = lr.user_id
    left join CommentsGiven cg on u.id = cg.user_id
    left join CommentsReceived cr on u.id = cr.user_id
    left join PhotosUploaded pu on u.id = pu.user_id
    left join Followers f on u.id = f.user_id
    left join Followings fg on u.id = fg.user_id
)
select 
    user_id,
    username,
    total_engagement,
    rank() over (order by total_engagement desc) as engagement_rank
from Engagement
order by engagement_rank;

-- Q2 For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?
with LastActivity as 
(
    select 
        u.id as user_id,
        MAX(GREATEST(
            (l.created_at),
            (c.created_at),
            (p.created_dat)
        )) as last_activity
    from users u
    left join likes l on u.id = l.user_id
    left join comments c on u.id = c.user_id
    left join photos p on u.id = p.user_id
    group by u.id
)
select 
    u.id,
    u.username,
    la.last_activity
from users u
join LastActivity la ON u.id = la.user_id
where la.last_activity < NOW() - interval 3 month;

-- Q3 Which hashtags or content topics have the highest engagement rates? How can this information guide content strategy and ad campaigns?
with PhotoEngagement as 
(
    select 
        p.id as photo_id,
        coalesce(COUNT(distinct l.user_id), 0) + coalesce(COUNT(distinct c.id), 0) AS total_engagement
    from photos p
    left join likes l on p.id = l.photo_id
    left join comments c on p.id = c.photo_id
    group by p.id
),
HashtagEngagement as 
(
    select 
        t.id as tag_id,
        t.tag_name,
        coalesce(SUM(pe.total_engagement), 0) as total_engagement
    from tags t
    left join photo_tags pt on t.id = pt.tag_id
    left join PhotoEngagement pe on pt.photo_id = pe.photo_id
    group by t.id, t.tag_name
)
select 
    tag_name,
    total_engagement
from HashtagEngagement
order by total_engagement desc ;











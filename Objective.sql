show tables;

desc ball_by_ball;

use ipl;


-- Question 1-Objective 

Select column_name, data_type
from information_schema.columns
where table_name = 'ball_by_ball';

-- Question 2-Objective 
with rcb as (
  select team_id
  from team
WHERE Team_Name = 'Royal Challengers Bangalore'
  
),
first_season as (
  select min(m.season_id) as season_id
  from matches m
  join rcb on m.team_1 = rcb.team_id or m.team_2 = rcb.team_id
),
rcbmatches as (
  select m.*
  from matches m
  join first_season fs on fs.season_id = m.season_id
  join rcb on m.team_1 = rcb.team_id or m.team_2 = rcb.team_id
)
select
  sum(b.runs_scored + coalesce(er.extra_runs, 0)) as total_runs_rcb_first_season
from rcbmatches r
join ball_by_ball b
  on b.match_id = r.match_id
 and b.team_batting = (select team_id from rcb)
left join extra_runs er
  on er.match_id  = b.match_id
 and er.innings_no = b.innings_no
 and er.over_id   = b.over_id
 and er.ball_id   = b.ball_id;

   
-- Question 3 -Objective  
with agedata as (Select *,timestampdiff(YEAR, DOB, '2014-01-01') as agein2014
from player)

Select count(distinct Player_Id) as players_older_than_25_in_2014
from player_match
where Player_Id in (Select Player_Id   -- Filter by age>25
from agedata 
where agein2014 > 25)
and Match_id in (Select Match_Id
from matches 
where Season_Id = (Select Season_Id   -- Filter by 2014 Season
from season
where Season_Year ='2014'));
   
-- Question 4 -Objective  
With RCBteamid as (
    select Team_Id
    from team
    where Team_Name = 'Royal Challengers Bangalore')
,Season2013 as (
    Select Season_Id
    from season
    where Season_Year = '2013')
Select COUNT(Match_Id) as matches_won_by_RCB
from matches
where Season_Id = (Select Season_Id from Season2013)  -- Filter by 2013 Season
and Match_Winner = (Select Team_Id from RCBteamid); -- Filter where RCB is the winner


-- Question 5 -Objective  

with Last_Seasons as (
    -- 1. Find the Season_Ids for the last 4 years
    select Season_Id
    from season
   order by Season_Year desc
    limit 4 
)
select
    P.Player_Name,
    (SUM(BBB.Runs_Scored) * 100.0) / COUNT(BBB.Ball_id) as Strike_Rate
from
    ball_by_ball as BBB
join
    player as P on BBB.Striker = P.Player_Id
join
    matches as M on BBB.Match_Id = M.Match_Id
where
    -- 2. Filter matches using the Season_Ids found in the CTE
    M.Season_Id in (SELECT Season_Id from Last_Seasons)
group by
    P.Player_Id, P.Player_Name
having
    -- 3. Apply a minimum balls faced qualification 
    COUNT(BBB.Ball_id) >= 100
order by 
    Strike_Rate desc
limit 10;

-- Question 6 Objective What are the average runs scored by each batsman considering all the seasons?

with batting_avg1 as (Select player_id,player_name,sum(runs_scored)as total_runs_scored
from 
ball_by_ball bbb
JOIN 
player p on bbb.striker=p.player_id
group by player_id,player_name)

,batting_avg2 as (Select player_id,player_name,count(wt.ball_id) as total_times_out
from 
player p
JOIN 
wicket_taken wt on p.player_id=wt.player_out
group by player_id,player_name)

select
    a1.player_id,
    a1.player_name,
    case
        -- If Total_Times_Out is 0 (player never dismissed), return NULL or special value
        when a2.total_times_out is null or a2.total_times_out = 0 then null 
        -- Otherwise, calculate the average
        else (a1.total_runs_scored * 1.0) / a2.total_times_out 
    end as BattingAvg
from batting_avg1 a1
left join batting_avg2 a2 on a1.player_id = a2.player_id
order by BattingAvg desc
limit 20;

-- Question-7.	What are the average wickets taken by each bowler considering all the seasons?
with Bowler_Runs as (
        Select  BBB.Bowler as Player_Id,
        SUM(BBB.Runs_Scored + er.Extra_Runs) as Total_Runs_Conceded
        -- Total Runs Conceded
    from ball_by_ball  BBB
        JOIN extra_runs er on BBB.ball_id=er.ball_id
    GROUP BY BBB.Bowler
),
Bowler_Wickets as (
    -- Total Wickets Taken
    Select BBB.Bowler as Player_Id,COUNT(WT.Ball_Id) as Total_Wickets
    from wicket_taken  WT
    JOIN ball_by_ball BBB on WT.Ball_Id = BBB.Ball_Id
    where
        WT.kind_out in (1, 2, 4, 6, 7, 8) -- Corresponds to caught, bowled, lbw, stumped, caught and bowled, hit wicket
	group by BBB.Bowler
)
Select P.Player_Name, BR.Total_Runs_Conceded, coalesce(BW.Total_Wickets, 0) as Total_Wickets_Taken,
        -- Prevent division by zero: if wickets are 0 or NULL
        case
        when BW.Total_Wickets is null or BW.Total_Wickets = 0 then null
        else (BR.Total_Runs_Conceded ) / BW.Total_Wickets
    end as Bowling_Average
from Bowler_Runs BR
LEFT JOIN player P on BR.Player_Id = P.Player_Id
LEFT JOIN Bowler_Wickets  BW on BR.Player_Id = BW.Player_Id
order by Bowling_Average asc
limit 20; 

-- Question 8 Objective 
with playerbattingstats as (
  select p.player_id, p.player_name, sum(bbb.runs_scored) as total_runs_scored
  from ball_by_ball bbb
  join player p on bbb.striker = p.player_id
  group by p.player_id, p.player_name
),
playerdismissals as (
  select wt.player_out as player_id, count(*) as total_times_out
  from wicket_taken wt
  group by wt.player_out
),
playerbattingaverage as (
  select s.player_id, s.player_name,
         case when coalesce(d.total_times_out,0) = 0 then null
              else (s.total_runs_scored) / d.total_times_out end as batting_avg
  from playerbattingstats s
  left join playerdismissals d on s.player_id = d.player_id
),
playerbowlingstats as (
  select bb.bowler as player_id, count(*) as total_wickets
  from wicket_taken wt
  join ball_by_ball bb
    on bb.match_id  = wt.match_id
   and bb.innings_no = wt.innings_no
   and bb.over_id    = wt.over_id
   and bb.ball_id    = wt.ball_id
    join out_type ot on ot.out_id = wt.kind_out
 where  ot.out_name not  in ('caught','run out ','retired hurt','stumped','obstructing the field')
  group by bb.bowler
),
overall as (
  select
    (select avg(batting_avg) from playerbattingaverage) as overall_batting_avg,
    (select avg(total_wickets) from playerbowlingstats) as overall_wickets_avg
)
select
  pba.player_id,
  pba.player_name,
  round(pba.batting_avg, 2) as batting_avg,
  pbs.total_wickets,
  round(o.overall_batting_avg, 2) as overall_batting_avg,
  round(o.overall_wickets_avg, 2) as overall_wickets_avg
from playerbattingaverage pba
join playerbowlingstats pbs on pba.player_id = pbs.player_id
cross join overall o
where pba.batting_avg > o.overall_batting_avg
  and pbs.total_wickets > o.overall_wickets_avg
order by pba.batting_avg desc, pbs.total_wickets desc;

-- Question 9 Objective
create table rcb_record as
select
  v.venue_name,
  sum(case when (m.team_1 = (SELECT Team_Id
    from team
    where Team_Name = 'Royal Challengers Bangalore') OR m.team_2 = (SELECT Team_Id
    from team
    where Team_Name = 'Royal Challengers Bangalore')) 
               and m.match_winner = (SELECT Team_Id
    from team
    WHERE Team_Name = 'Royal Challengers Bangalore') then 1 else 0 end) as wins,
  sum(case when (m.team_1 =(Select Team_Id
    from team
    where Team_Name = 'Royal Challengers Bangalore') or m.team_2 = (Select Team_Id
    from team
    where Team_Name = 'Royal Challengers Bangalore')) and m.match_winner != (Select Team_Id
    from team
    where Team_Name = 'Royal Challengers Bangalore') then 1 else 0 end) as losses
from matches m
join venue v on m.venue_id = v.venue_id
group by  v.venue_name;
Select *
from rcb_record;

-- Question 10 Objective 
select
  bs.bowling_skill,
  count(*) as total_wickets
from wicket_taken wt
join ball_by_ball bb
  on bb.match_id  = wt.match_id
 and bb.innings_no = wt.innings_no
 and bb.over_id    = wt.over_id
 and bb.ball_id    = wt.ball_id
join player p
  on p.player_id = bb.bowler
join bowling_style bs
  on bs.bowling_id = p.bowling_skill
  where wt.kind_out not in (Select out_id from out_type 
  where out_name in ('caught','run out ','retired hurt','stumped','obstructing the field'))
group by
  bs.bowling_skill
order by
  total_wickets desc;

-- Question 11 Objective
with RCBteamid as (
    Select Team_Id from team where Team_Name = 'Royal Challengers Bangalore'
),
RCBseasons as (
    Select m.Match_Id, s.Season_Year
    from matches m
    join season s on m.Season_Id = s.Season_Id
    cross join RCBteamid rcb
    where (m.Team_1 = rcb.Team_Id OR m.Team_2 = rcb.Team_Id)
        and s.Season_Year IN (2015, 2016)
),
RCB_runs as (
    Select rs.Season_Year,sum(bbb.Runs_Scored + coalesce(er.Extra_Runs, 0)) as total_runs
    from ball_by_ball bbb
    join RCBseasons rs on bbb.Match_Id = rs.Match_Id
    left join extra_runs er on bbb.Ball_Id = er.Ball_Id
    join RCBteamid rcb on bbb.Team_Batting = rcb.Team_Id
    group by rs.Season_Year
),
RCB_wickets as (
    select rs.Season_Year, count(wt.Ball_Id) as total_wickets
    from ball_by_ball bbb
    join RCBseasons rs on bbb.Match_Id = rs.Match_Id
    join RCBteamid rcb on bbb.Team_Bowling = rcb.Team_Id
    left join wicket_taken wt on bbb.Ball_Id = wt.Ball_Id
    where wt.Ball_Id is not null
    group by  rs.Season_Year
),
RCB_performance as (
    select r.Season_Year,r.total_runs, w.total_wickets
    from RCB_runs r
    join RCB_wickets w on r.Season_Year = w.Season_Year)
Select p2016.Season_Year as `Year`,p2016.total_runs as Runs_Scored,p2015.total_runs as Prev_Year_Runs,
    case when p2016.total_runs > p2015.total_runs then 'Improved'
        when p2016.total_runs < p2015.total_runs then 'Declined'
        else 'Same' 
    end as Runs_Status,
    p2016.total_wickets as Wickets_Taken,
    p2015.total_wickets as Prev_Year_Wkts,
    case 
        when p2016.total_wickets > p2015.total_wickets then 'Improved'
        when p2016.total_wickets < p2015.total_wickets then 'Declined'
        else 'Same' 
    end as Wickets_Status
from RCB_performance p2016
join RCB_performance p2015 on p2016.Season_Year = 2016 AND p2015.Season_Year = 2015;

-- Question 12 Objective 

with rcb as (
  select team_id
  from team
  where lower(team_name) = 'royal challengers bangalore'
),
team_matches as (
  select m.match_id, m.season_id
  from matches m
  join rcb on m.team_1 = rcb.team_id or m.team_2 = rcb.team_id
),
balls as (
  select
    b.match_id, b.innings_no, b.over_id, b.ball_id,
    b.team_batting, b.team_bowling, b.striker, b.non_striker, b.bowler,
    b.runs_scored,
    coalesce(er.extra_runs, 0) as extra_runs,
    (b.runs_scored + coalesce(er.extra_runs, 0)) as total_runs
  from ball_by_ball b
  join team_matches tm on tm.match_id = b.match_id
  left join extra_runs er
    on er.match_id  = b.match_id
   and er.innings_no = b.innings_no
   and er.over_id    = b.over_id
   and er.ball_id    = b.ball_id
)

-- Powerplay batting (overs 1–6)
select
  sum(total_runs) as pp_runs,
  sum(case when wt.ball_id is not null then 1 else 0 end) as pp_wkts,
  round(6.0 * sum(total_runs) / nullif(count(*),0), 2) as pp_run_rate,
  round(100.0 * sum(case when runs_scored in (4,6) then 1 else 0 end) / nullif(count(*),0), 2) as pp_boundary_pct,
  round(100.0 * sum(case when runs_scored = 0 and extra_runs = 0 then 1 else 0 end) / nullif(count(*),0), 2) as pp_dot_pct
from balls b
left join wicket_taken wt
  on wt.match_id = b.match_id and wt.innings_no = b.innings_no
 and wt.over_id  = b.over_id  and wt.ball_id    = b.ball_id
join rcb on b.team_batting = rcb.team_id
where b.over_id between 1 and 6;

-- Powerplay bowling (overs 1–6)
select
  round(6.0 * sum(total_runs) / nullif(count(*),0), 2) as pp_economy,
  sum(case when wt.ball_id is not null then 1 else 0 end) as pp_wkts_conceded,
  round(100.0 * sum(case when runs_scored = 0 and extra_runs = 0 then 1 else 0 end) / nullif(count(*),0), 2) as pp_dot_pct_bowling
from balls b
left join wicket_taken wt
  on wt.match_id = b.match_id and wt.innings_no = b.innings_no
 and wt.over_id  = b.over_id  and wt.ball_id    = b.ball_id
join rcb on b.team_bowling = rcb.team_id
where b.over_id between 1 and 6;

-- Fielding efficiency (catches and runouts)

select
  sum(case when ot.out_name = 'caught' then 1 else 0 end) as catches,
  sum(case when ot.out_name = 'run out' then 1 else 0 end) as run_outs
from wicket_taken wt
join out_type ot on ot.out_id = wt.kind_out
join balls b
  on b.match_id = wt.match_id and b.innings_no = wt.innings_no
 and b.over_id  = wt.over_id  and b.ball_id    = wt.ball_id
join rcb on b.team_bowling = rcb.team_id;

-- Bowling strike rate and economy

select round(6.0 * count(*) / coalesce(sum(case when wt.ball_id is not null then 1 else 0 end),0), 2) as bowling_strike_rate_balls_per_wkt,
  round(6.0 * sum(total_runs) / coalesce(count(*),0), 2) as bowling_economy
from balls b
left join wicket_taken wt
  on wt.match_id = b.match_id and wt.innings_no = b.innings_no
 and wt.over_id  = b.over_id  and wt.ball_id    = b.ball_id
join rcb on b.team_bowling = rcb.team_id;

-- Boundary rate and dotball rate (season aggregate)
select
  round(100.0 * avg(case when runs_scored in (4,6) then 1 else 0 end), 2) as boundary_ball_pct,
  round(100.0 * avg(case when runs_scored = 0 and extra_runs = 0 then 1 else 0 end), 2) as dot_ball_pct
from balls b join rcb on b.team_batting = rcb.team_id;

-- Question 13 Write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value.
-- CTE 1: Lists every match a bowler played in (used to count total games).
with bowler_matches as (
    select distinct
        match_id,
        bowler
    from
        ball_by_ball
),

-- CTE 2: Counts wickets taken by each bowler in each match.
wickets_per_match as (
    select
        BBB.match_id,
        BBB.bowler,
        count(WT.ball_id) as wickets_taken
    from
        ball_by_ball BBB
    join
        wicket_taken WT on BBB.match_id = WT.match_id and BBB.ball_id = WT.ball_id
    group by
        BBB.match_id, BBB.bowler
),

-- CTE 3: Joins all match, player, and venue details.
bowler_venue_stats as (
    select
        V.venue_name,
        P.player_name,
        coalesce(WPM.wickets_taken, 0) as wickets,
        BM.match_id
    from
        bowler_matches BM
    join
        matches M on BM.match_id = M.match_id
    join
        venue V on M.venue_id = V.venue_id
    join
        player P on BM.bowler = P.player_id
    left join
        wickets_per_match WPM on BM.match_id = WPM.match_id and BM.bowler = WPM.bowler
),

-- CTE 4: Calculates the total wickets, total matches, and the average per bowler/venue.
final_summary as (
    select
        venue_name,
        player_name,
        sum(wickets) as total_wickets,
        count(match_id) as total_matches,
        -- Calculates the average (uses 1.0 multiplier for decimal results).
        (cast(sum(wickets) as real) * 1.0) / count(match_id) as avg_wickets_per_match
    from
        bowler_venue_stats
    group by
        venue_name, player_name
)

-- Final SELECT: Ranks the bowlers within each venue by their average wickets.
select
    venue_name,
    player_name,
    total_wickets,
    total_matches,
    round(avg_wickets_per_match, 2) as average_wickets_per_match,
    -- Ranks bowlers from highest average to lowest, resetting the rank for each venue.
    dense_rank() over (partition by venue_name order by avg_wickets_per_match desc) as venue_rank
from
    final_summary
order by
    venue_name, venue_rank
    limit 20;


-- Question 14 
-- It only includes players who have met the "consistent" threshold (>= 6 seasons with 300+ runs).

-- CTE 1: Calculate the total runs scored by each player in each season.
with player_season_runs as (
    select
        T1.striker,
        P.player_name,
        S.season_year,
        sum(T1.runs_scored) as total_runs_scored
    from
        ball_by_ball T1
    join
        matches M on T1.match_id = M.match_id
    join
        season S on M.season_id = S.season_id
    join
        player P on T1.striker = P.player_id
    group by
        T1.striker, P.player_name, S.season_year
),

consistent_performer_counts as (
    select
        player_name,
        count(season_year) as seasons_above_threshold
    from
        player_season_runs
    where
        -- threshold above 300
        total_runs_scored >= 300
    group by
        player_name
),

-- CTE 3 (NEW): Selects only the names of the players who meet the consistency criteria (>= 6 seasons).
final_consistent_players as (
    select
        player_name
    from
        consistent_performer_counts
    where
        seasons_above_threshold >= 4 -- Uses the required threshold of 6 out of 9 seasons
)

-- Final SELECT: Gets the detailed season-by-season run data
-- for only the players identified as consistent performers (from CTE 3).
select
    PSR.player_name,
    PSR.season_year,
    PSR.total_runs_scored
from
    player_season_runs PSR
join
    final_consistent_players FCP on PSR.player_name = FCP.player_name
order by
    PSR.player_name,
    PSR.season_year asc;



-- Question 15 
with aggregated_extras as (
    select ball_id, sum(extra_runs) as total_extra_runs
    from extra_runs
    group by ball_id
),
player_venue_runs as (
    select
        p.player_name,
        v.venue_name,
        sum(bbb.runs_scored + coalesce(ae.total_extra_runs, 0)) as total_runs
    from
        ball_by_ball bbb
    join matches m on bbb.match_id = m.match_id
    join season s on m.season_id = s.season_id
    join venue v on m.venue_id = v.venue_id
    join player p on bbb.striker = p.player_id
    left join aggregated_extras ae on bbb.ball_id = ae.ball_id
    group by
        p.player_name, v.venue_name
)
select *
from player_venue_runs
order by player_name, total_runs desc
limit 20;








-- Subjective Questions 

-- Subjective Question 1 

with toss_match_summary as (
    select
        m.match_id,
        v.venue_name,
        td.toss_name as toss_decide,
        case
            when m.toss_winner = m.match_winner then 1
            else 0
        end as toss_winner_won
    from
        matches m
    join toss_decision td on m.toss_decide = td.toss_id
    join venue v on m.venue_id = v.venue_id
    join outcome ot on m.Outcome_Type = ot.outcome_id
    where m.outcome_type = 1  -- only those matches with a result 
)
select
    venue_name,
    toss_decide,
    count(*) as total_matches,
    sum(toss_winner_won) as matches_won_by_toss_winner,
    round(100.0 * sum(toss_winner_won) / count(*), 2) as win_pct_toss_winner
from toss_match_summary
group by venue_name, toss_decide
order by venue_name, toss_decide;

-- Subjective Question 2 & 3
with batsman_stats as (
    select
        p.player_id,
        p.player_name,
        sum(bbb.runs_scored) as total_runs
    from
        ball_by_ball bbb
    join player p on bbb.striker = p.player_id
    group by p.player_id, p.player_name
),

top_batsmen as (
    select player_id, player_name, total_runs
    from batsman_stats
    order by total_runs desc
    limit 5
),

bowler_wickets as (
    select
        bbb.bowler as player_id,
        count(*) as total_wickets
    from
        wicket_taken wt
    join ball_by_ball bbb on wt.ball_id = bbb.ball_id
    group by bbb.bowler
),

top_bowlers as (
    select p.player_id, p.player_name, bw.total_wickets
    from bowler_wickets bw
    join player p on bw.player_id = p.player_id
    order by bw.total_wickets desc
    limit 5
),

allrounder_stats as (
    select
        ba.player_id,
        ba.player_name,
        ba.total_runs,
        coalesce(bw.total_wickets, 0) as total_wickets
    from batsman_stats ba
    join bowler_wickets bw on ba.player_id = bw.player_id
    where ba.total_runs > 1000 and bw.total_wickets > 30
),

top_allrounders as (
    select player_id, player_name, total_runs, total_wickets
    from allrounder_stats
    order by (total_runs + total_wickets*20) desc
    limit 2
),

keepers as (
    select distinct p.player_id, p.player_name, bs.total_runs
    from player p
    join player_match pm on p.player_id = pm.player_id
    join rolee r on pm.role_id = r.role_id
    join batsman_stats bs on p.player_id = bs.player_id
    where r.role_desc in ('keeper', 'captainkeeper')
),

top_keeper as (
    select player_id, player_name
    from keepers
    order by total_runs desc
    limit 1
),

final_team_raw as (
    select player_id, player_name, 'Batsman' as role from top_batsmen
    union all
    select player_id, player_name, 'Bowler' as role from top_bowlers
    union all
    select player_id, player_name, 'Allrounder' as role from top_allrounders
),

final_team as (
    -- Add the keeper if not already included
    select * from final_team_raw
    union all
    select player_id, player_name, 'Keeper' from top_keeper
    where player_id not in (select player_id from final_team_raw)
)

select * from final_team
limit 12;

-- Question 4 Subjective 

with batsman_stats as (
    select
        p.player_id,
        p.player_name,
        sum(bbb.runs_scored) as total_runs
    from
        ball_by_ball bbb
    join player p on bbb.striker = p.player_id
    group by p.player_id, p.player_name
),
bowler_stats as (
    select
        bbb.bowler as player_id,
        count(*) as total_wickets
    from
        wicket_taken wt
    join ball_by_ball bbb on wt.ball_id = bbb.ball_id
    where wt.kind_out in (1,2,4,7,8)
    group by bbb.bowler
),
allrounder_stats as (
    select
        b.player_id,
        bs.player_name,
        bs.total_runs,
        b.total_wickets
    from bowler_stats b
    join batsman_stats bs on b.player_id = bs.player_id
    where bs.total_runs > 1000 and b.total_wickets > 30
)
select
    player_id,
    player_name,
    total_runs,
    total_wickets,
    (total_runs + total_wickets*20) as allrounder_score
from
    allrounder_stats
order by allrounder_score desc;

-- Question 5 Subjective 

Select player_id,player_name,team_name,matches_played,wins_with_player,win_percentage_with_player
from (select p.player_id,p.player_name,pm.team_id,t.team_name,
    count(distinct pm.match_id) as matches_played,
    count(distinct case when m.match_winner = pm.team_id then pm.match_id end) as wins_with_player,
    round(
        100.0 * count(distinct case when m.match_winner = pm.team_id then pm.match_id end)
        / coalesce(count(distinct pm.match_id), 1), 2
    ) as win_percentage_with_player
from player_match pm
join player p on pm.player_id = p.player_id
join matches m on pm.match_id = m.match_id
join team t on pm.team_id = t.team_id
group by p.player_id, p.player_name, pm.team_id, t.team_name) final
where win_percentage_with_player>60
limit 20;


-- Question 7 Subjective 
select v.venue_name, sum(bbb.runs_scored) + sum(coalesce(er.extra_runs, 0)) as total_runs
from ball_by_ball bbb
join matches m on bbb.match_id = m.match_id
join venue v on m.venue_id = v.venue_id
left join extra_runs er on bbb.match_id = er.match_id and bbb.over_id = er.over_id and bbb.ball_id = er.ball_id
group by v.venue_name
order by total_runs desc;

-- Question 8 Subjective 

select v.venue_name,
       sum(case when (m.team_1 = rcb.team_id or m.team_2 = rcb.team_id) and m.match_winner = rcb.team_id then 1 else 0 end) as wins,
       sum(case when (m.team_1 = rcb.team_id or m.team_2 = rcb.team_id) and m.match_winner != rcb.team_id then 1 else 0 end) as losses
from matches m
join venue v on m.venue_id = v.venue_id
join (select team_id from team where team_name = 'Royal Challengers Bangalore') rcb
group by v.venue_name
order by wins desc;

-- Question 9 Subjective 

-- a) season by season performance

select s.season_year,
    sum(case when m.match_winner = rcb.team_id then 1 else 0 end) as wins,
    sum(case when m.match_winner != rcb.team_id and (m.team_1 = rcb.team_id or m.team_2 = rcb.team_id) then 1 else 0 end) as losses
from matches m
join season s on m.season_id = s.season_id
join (select team_id from team where team_name = 'Royal Challengers Bangalore') rcb
group by s.season_year
order by s.season_year;


-- b) top 10 batsmen of rcb 

select p.player_name, sum(bbb.runs_scored) as total_runs
from ball_by_ball bbb
join player p on bbb.striker = p.player_id
join matches m on bbb.match_id = m.match_id
where m.team_1 = (select team_id from team where team_name = 'Royal Challengers Bangalore')
   or m.team_1 = (select team_id from team where team_name = 'Royal Challengers Bangalore')
group by p.player_name
order by total_runs desc
limit 10;

-- top 10 rcb bowlers 

select p.player_name, 
    count(distinct wkt.ball_id) as wickets_taken
from wicket_taken wkt
join player p on wkt.player_out = p.player_id
join matches m on wkt.match_id = m.match_id
where (m.team_1 = (select team_id from team where team_name = 'Royal Challengers Bangalore')
      or m.team_2 = (select team_id from team where team_name = 'Royal Challengers Bangalore'))
  and wkt.kind_out in (Select out_id from out_type
  where Out_Name in ('caught','bowled','lbw','caught and bowled','hit wicket'))
group by p.player_name
order by wickets_taken desc
limit 10;

-- venue by win and loss 
select v.venue_name,
       sum(case when (m.team_1 = rcb.team_id or m.team_2 = rcb.team_id) and m.match_winner = rcb.team_id then 1 else 0 end) as wins,
       sum(case when (m.team_1 = rcb.team_id or m.team_2 = rcb.team_id) and m.match_winner != rcb.team_id then 1 else 0 end) as losses
from matches m
join venue v on m.venue_id = v.venue_id
join (select team_id from team where team_name = 'Royal Challengers Bangalore') rcb
group by v.venue_name
order by wins desc;

-- Question 11  Subjective 
update team
set team_name = 'Delhi Daredevils'
where team_name = 'Delhi Capitals';
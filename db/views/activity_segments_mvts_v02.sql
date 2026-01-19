WITH zoom_levels AS (
  SELECT generate_series(0, 15) AS z
)
SELECT
  s.id,
  a.user_id,
  a.activity_type,
  a.name AS activity_name,
  a.start_time AS start_date,
  z.z AS zoom_level,
  CASE
    WHEN z.z < 10 THEN ST_Simplify(ST_Transform(s.geom, 3857), 200)
    WHEN z.z < 13 THEN ST_Simplify(ST_Transform(s.geom, 3857), 50)
    ELSE ST_Transform(s.geom, 3857)
  END AS geom
FROM activity_segments s
JOIN activities a ON s.activity_id = a.id
CROSS JOIN zoom_levels z
WHERE s.geom IS NOT NULL AND NOT ST_IsEmpty(s.geom) AND ST_Length(ST_Transform(s.geom, 3857)) > CASE
    WHEN z.z <= 7  THEN 500
    WHEN z.z <= 10 THEN 100
    ELSE 0
END;

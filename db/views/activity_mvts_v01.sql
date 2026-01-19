WITH zoom_levels AS (
  SELECT generate_series(0, 15) AS z
)
SELECT
  a.id,
  z.z AS zoom_level,
  CASE
    WHEN z.z < 10 THEN ST_Simplify(a.track_3857, 200)
    WHEN z.z < 13 THEN ST_Simplify(a.track_3857, 50)
    ELSE a.track_3857
  END AS geom
FROM activities a
CROSS JOIN zoom_levels z
WHERE a.track_3857 IS NOT NULL AND ST_Length(track_3857) > 0;

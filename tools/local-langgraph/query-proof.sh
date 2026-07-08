#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$ROOT_DIR"

echo "Recent graph runs"
npx supabase db query --local "
select
  id,
  graph_name,
  status,
  model_json->>'provider' as provider,
  source_fitness_strategy_id,
  source_training_architecture_id,
  created_at,
  finished_at
from ai_graph_runs
order by created_at desc
limit 10;
"

echo "Recent tool calls"
npx supabase db query --local "
select
  tool_name,
  status,
  graph_run_id,
  created_at
from ai_tool_calls
order by created_at desc
limit 20;
"

echo "Recent modality trace"
npx supabase db query --local "
select
  id,
  created_at,
  input_json #> '{goal_context,selected_modality_order}' as input_modalities,
  output_json #> '{trainingArchitecture,priority_order}' as architecture_modalities,
  output_json #>> '{fitnessStrategy,operatingRhythm,summary}' as strategy_rhythm_summary
from ai_graph_runs
where graph_name = 'training_architecture'
order by created_at desc
limit 5;
"

echo "Recent weekly plans and workouts"
npx supabase db query --local "
select
  wp.id,
  wp.status,
  wp.week_start_date,
  count(pw.id) as planned_workouts
from weekly_plans wp
left join planned_workouts pw on pw.weekly_plan_id = wp.id
group by wp.id, wp.status, wp.week_start_date
order by wp.week_start_date desc
limit 10;
"

echo "Recent planning targets"
npx supabase db query --local "
select
  id,
  scope,
  title,
  metric_key,
  target_value,
  created_at
from planning_targets
order by created_at desc
limit 20;
"

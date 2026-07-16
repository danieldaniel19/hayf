update public.fitness_strategies
set title = context_json #>> '{acceptedStrategy,goalTargetContext,title}'
where title in ('Goal Build Strategy', 'Fitness Strategy')
  and nullif(trim(context_json #>> '{acceptedStrategy,goalTargetContext,title}'), '') is not null;

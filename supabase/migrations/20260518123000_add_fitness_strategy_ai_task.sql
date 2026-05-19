alter table public.onboarding_ai_generations
    drop constraint if exists onboarding_ai_generations_task_check;

alter table public.onboarding_ai_generations
    add constraint onboarding_ai_generations_task_check
    check (
        task in (
            'generate_summary',
            'generate_first_rhythm',
            'generate_goal_candidates',
            'generate_blended_candidate',
            'generate_athlete_blueprint',
            'generate_fitness_strategy'
        )
    );

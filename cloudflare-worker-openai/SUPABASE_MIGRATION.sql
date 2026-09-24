alter table public."App_Config"
    add column if not exists image_generation_provider text not null default 'gemini';

alter table public."App_Config"
    drop constraint if exists app_config_image_generation_provider_check;

alter table public."App_Config"
    add constraint app_config_image_generation_provider_check
    check (image_generation_provider in ('gemini', 'openai'));

-- Keep Gemini active until the new app version and Worker are deployed.
update public."App_Config"
set image_generation_provider = 'gemini';

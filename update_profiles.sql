-- Add Custom Office and Device Binding columns to profiles
ALTER TABLE public.profiles
ADD COLUMN custom_office_latitude DOUBLE PRECISION,
ADD COLUMN custom_office_longitude DOUBLE PRECISION,
ADD COLUMN custom_office_radius INTEGER,
ADD COLUMN registered_device_id TEXT;

-- Current clients send only feedback content and the public App version.
-- Clear device, OS, and build diagnostics that may have been stored by an
-- earlier opt-in build; the Worker also ignores these fields going forward.

UPDATE feedback
SET device_family = '',
    os_version = '',
    build = ''
WHERE device_family <> ''
   OR os_version <> ''
   OR build <> '';

INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.domain',             'openfire')          ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.fqdn',               'openfire')          ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('plugin.restapi.enabled',   'true')              ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('plugin.restapi.secret',    '${OPENFIRE_TOKEN}') ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('plugin.restapi.httpAuth',  'secret')            ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);

-- Pre-create the XMPP engine user so it exists before core starts.
-- salt=NULL causes Openfire to compute SCRAM-SHA-1 hashes from plainPassword on first login.
INSERT INTO ofUser (username, plainPassword, name, email, creationDate, modificationDate)
VALUES (
    'sbrw.engine.engine',
    '${OPENFIRE_TOKEN}',
    'SBRW Engine',
    NULL,
    LPAD(CAST(UNIX_TIMESTAMP() * 1000 AS UNSIGNED), 15, '0'),
    LPAD(CAST(UNIX_TIMESTAMP() * 1000 AS UNSIGNED), 15, '0')
) ON DUPLICATE KEY UPDATE plainPassword = VALUES(plainPassword);
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.auth.iqauth',         'true')              ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('stream.management.active', 'false')             ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('xmpp.audit.active',        'false')             ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);
INSERT INTO ofProperty (name, propValue) VALUES ('adminConsole.access.allow-wildcards-in-excludes', 'true') ON DUPLICATE KEY UPDATE propValue = VALUES(propValue);

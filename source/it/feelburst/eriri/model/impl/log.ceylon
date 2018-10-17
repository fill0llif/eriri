import ceylon.logging {
	Logger,
	logger,
	info
}

shared Logger log {
	value log = logger(`package it.feelburst.eriri.model.impl`);
	log.priority = info;
	return log;
}
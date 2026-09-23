package com.suachuabientan.system_internal.common.logging;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationFailedEvent;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.ContextClosedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.net.InetAddress;
import java.time.Instant;

@Slf4j
@Component
public class ApplicationLifecycleLogging {
    private final Environment environment;
    private final String instanceId;

    public ApplicationLifecycleLogging(Environment environment) {
        this.environment = environment;
        this.instanceId = environment.getProperty("app.instance-id", "unknown-instance");
    }

    @EventListener
    public void onReady(ApplicationReadyEvent event) {
        log.info("server.lifecycle event=READY instance_id={} pid={} host={} profile={} port={} timestamp={}",
                instanceId, ProcessHandle.current().pid(), hostName(), activeProfiles(),
                environment.getProperty("server.port", "8080"), Instant.now());
    }

    @EventListener
    public void onClosed(ContextClosedEvent event) {
        log.warn("server.lifecycle event=SHUTDOWN instance_id={} pid={} host={} timestamp={}",
                instanceId, ProcessHandle.current().pid(), hostName(), Instant.now());
    }

    @EventListener
    public void onFailed(ApplicationFailedEvent event) {
        log.error("server.lifecycle event=STARTUP_FAILED instance_id={} pid={} host={} timestamp={}",
                instanceId, ProcessHandle.current().pid(), hostName(), Instant.now(), event.getException());
    }

    private String activeProfiles() {
        String[] profiles = environment.getActiveProfiles();
        return profiles.length == 0 ? "default" : String.join(",", profiles);
    }

    private String hostName() {
        try {
            return InetAddress.getLocalHost().getHostName();
        } catch (Exception error) {
            return "unknown";
        }
    }
}

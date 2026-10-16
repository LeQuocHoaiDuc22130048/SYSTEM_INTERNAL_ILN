package com.suachuabientan.system_internal.modules.banner.service;
import org.junit.jupiter.api.Test;
import org.yaml.snakeyaml.Yaml;
import java.nio.file.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
class BannerStorageDeploymentTest {
 @Test void productionAndTestUploadsUseSeparateExternalVolumes()throws Exception {
  verify("docker-compose.yml","backend_uploads_data");
  verify("docker-compose.test.yml","backend_test_uploads_data");
 }
 @SuppressWarnings("unchecked")
 private void verify(String file,String volumeName)throws Exception {
  Map<String,Object> compose=new Yaml().load(Files.readString(Path.of(file)));
  var backend=(Map<String,Object>)((Map<String,Object>)compose.get("services")).get("backend");
  assertTrue(((List<Object>)backend.get("volumes")).contains("uploads_data:/app/uploads"),file+" must persist uploaded images independently of the container");
  assertEquals("/app/uploads/banners",((Map<String,Object>)backend.get("environment")).get("APP_BANNER_UPLOAD_DIR"));
  var volume=(Map<String,Object>)((Map<String,Object>)compose.get("volumes")).get("uploads_data");
  assertEquals(true,volume.get("external"),"down -v must not remove uploaded images");
  assertEquals(volumeName,volume.get("name"));
 }
}

/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.seata.namingserver;

import org.apache.seata.common.metadata.Cluster;
import org.apache.seata.common.metadata.Node;
import org.apache.seata.common.metadata.namingserver.MetaResponse;
import org.apache.seata.common.metadata.namingserver.NamingServerNode;
import org.apache.seata.common.metadata.namingserver.Unit;
import org.apache.seata.common.result.Result;
import org.apache.seata.namingserver.controller.NamingController;
import org.apache.seata.namingserver.manager.NamingManager;
import org.junit.jupiter.api.Test;
import org.junit.runner.RunWith;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.junit4.SpringRunner;

import java.lang.reflect.Field;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.TimeUnit;


import static org.apache.seata.common.NamingServerConstants.CONSTANT_GROUP;
import static org.junit.jupiter.api.Assertions.*;


@RunWith(SpringRunner.class)
@SpringBootTest
class NamingControllerTest {

    @Value("${heartbeat.threshold}")
    private int threshold;

    @Value("${heartbeat.period}")
    private int period;
    @Autowired
    NamingController namingController;


    @Test
    void mockRegister() {
        String clusterName = "cluster1";
        String namespace = "public1";
        String vGroup = "mockRegister";
        String unitName = String.valueOf(UUID.randomUUID());
        NamingServerNode node = new NamingServerNode();
        node.setTransaction(new Node.Endpoint("127.0.0.1", 8091, "netty"));
        node.setControl(new Node.Endpoint("127.0.0.1", 7091, "http"));
        Map<String, Object> meatadata = node.getMetadata();
        Map<String, Object> vGroups = new HashMap<>();
        vGroups.put(vGroup, unitName);
        meatadata.put(CONSTANT_GROUP, vGroups);
        namingController.registerInstance(namespace, clusterName, unitName, node);
        namingController.changeGroup(namespace, clusterName, unitName, vGroup);
        MetaResponse metaResponse = namingController.discovery(vGroup, namespace);
        assertNotNull(metaResponse);
        assertNotNull(metaResponse.getClusterList());
        assertEquals(1, metaResponse.getClusterList().size());
        Cluster cluster = metaResponse.getClusterList().get(0);
        assertNotNull(cluster.getUnitData());
        assertEquals(1, cluster.getUnitData().size());
        Unit unit = cluster.getUnitData().get(0);
        assertNotNull(unit.getNamingInstanceList());
        assertEquals(1, unit.getNamingInstanceList().size());
        Node node1 = unit.getNamingInstanceList().get(0);
        assertEquals("127.0.0.1", node1.getTransaction().getHost());
        assertEquals(8091, node1.getTransaction().getPort());
        namingController.unregisterInstance(namespace, clusterName, unitName, node);
    }

    @Test
    void mockUnregisterGracefully() {
        String clusterName = "cluster2";
        String namespace = "public2";
        String vGroup = "mockUnregisterGracefully";
        String unitName = String.valueOf(UUID.randomUUID());
        NamingServerNode node = new NamingServerNode();
        node.setTransaction(new Node.Endpoint("127.0.0.1", 8092, "netty"));
        node.setControl(new Node.Endpoint("127.0.0.1", 7092, "http"));
        Map<String, Object> meatadata = node.getMetadata();
        Map<String, Object> vGroups = new HashMap<>();
        vGroups.put(vGroup, unitName);
        meatadata.put(CONSTANT_GROUP, vGroups);
        namingController.registerInstance(namespace, clusterName, unitName, node);
        NamingServerNode node2 = new NamingServerNode();
        node2.setTransaction(new Node.Endpoint("127.0.0.1", 8093, "netty"));
        node2.setControl(new Node.Endpoint("127.0.0.1", 7093, "http"));
        Map<String, Object> meatadata2 = node2.getMetadata();
        Map<String, Object> vGroups2 = new HashMap<>();
        String unitName2 = UUID.randomUUID().toString();
        vGroups2.put(UUID.randomUUID().toString(), unitName2);
        meatadata2.put(CONSTANT_GROUP, vGroups2);
        namingController.registerInstance(namespace, UUID.randomUUID().toString(), unitName2, node2);
        MetaResponse metaResponse = namingController.discovery(vGroup, namespace);
        assertNotNull(metaResponse);
        assertNotNull(metaResponse.getClusterList());
        assertEquals(1, metaResponse.getClusterList().size());
        Cluster cluster = metaResponse.getClusterList().get(0);
        assertNotNull(cluster.getUnitData());
        assertEquals(1, cluster.getUnitData().size());
        Unit unit = cluster.getUnitData().get(0);
        assertNotNull(unit.getNamingInstanceList());
        assertEquals(1, unit.getNamingInstanceList().size());
        Node node1 = unit.getNamingInstanceList().get(0);
        assertEquals("127.0.0.1", node1.getTransaction().getHost());
        assertEquals(8092, node1.getTransaction().getPort());
        namingController.unregisterInstance(namespace, clusterName, unitName, node);
        metaResponse = namingController.discovery(vGroup, namespace);
        assertNotNull(metaResponse);
        assertNotNull(metaResponse.getClusterList());
        assertEquals(0, metaResponse.getClusterList().get(0).getUnitData().size());
    }

    @Test
    void mockUnregisterUngracefully() throws InterruptedException {
        String clusterName = "cluster3";
        String namespace = "public3";
        String vGroup = "mockUnregisterUngracefully";
        String unitName = String.valueOf(UUID.randomUUID());
        NamingServerNode node = new NamingServerNode();
        node.setTransaction(new Node.Endpoint("127.0.0.1", 8094, "netty"));
        node.setControl(new Node.Endpoint("127.0.0.1", 7094, "http"));
        Map<String, Object> meatadata = node.getMetadata();
        Map<String, Object> vGroups = new HashMap<>();
        vGroups.put(vGroup, unitName);
        meatadata.put(CONSTANT_GROUP, vGroups);
        namingController.registerInstance(namespace, clusterName, unitName, node);
        //namingController.changeGroup(namespace, clusterName, vGroup, vGroup);
        MetaResponse metaResponse = namingController.discovery(vGroup, namespace);
        assertNotNull(metaResponse);
        assertNotNull(metaResponse.getClusterList());
        assertEquals(1, metaResponse.getClusterList().size());
        Cluster cluster = metaResponse.getClusterList().get(0);
        assertNotNull(cluster.getUnitData());
        assertEquals(1, cluster.getUnitData().size());
        Unit unit = cluster.getUnitData().get(0);
        assertNotNull(unit.getNamingInstanceList());
        assertEquals(1, unit.getNamingInstanceList().size());
        Node node1 = unit.getNamingInstanceList().get(0);
        assertEquals("127.0.0.1", node1.getTransaction().getHost());
        assertEquals(8094, node1.getTransaction().getPort());
        int timeGap = threshold + period;
        Thread.sleep(timeGap);
        metaResponse = namingController.discovery(vGroup, namespace);
        assertNotNull(metaResponse);
        assertNotNull(metaResponse.getClusterList());
        assertEquals(0, metaResponse.getClusterList().get(0).getUnitData().size());
    }

    @Test
    void mockDiscoveryMultiNode() {
        String clusterName = "cluster4";
        String namespace = "public4";
        String vGroup = "mockDiscoveryMultiNode";
        String unitName = String.valueOf(UUID.randomUUID());
        NamingServerNode node = new NamingServerNode();
        node.setTransaction(new Node.Endpoint("127.0.0.1", 8095, "netty"));
        node.setControl(new Node.Endpoint("127.0.0.1", 7095, "http"));
        Map<String, Object> meatadata = node.getMetadata();
        Map<String, Object> vGroups = new HashMap<>();
        vGroups.put(vGroup, unitName);
        meatadata.put(CONSTANT_GROUP, vGroups);
        NamingServerNode node2 = new NamingServerNode();
        String unitName2 = String.valueOf(UUID.randomUUID());
        node2.setTransaction(new Node.Endpoint("127.0.0.1", 8096, "netty"));
        node2.setControl(new Node.Endpoint("127.0.0.1", 7096, "http"));
        vGroups = new HashMap<>();
        vGroups.put(vGroup, unitName2);
        node2.getMetadata().put(CONSTANT_GROUP, vGroups);
        namingController.registerInstance(namespace, clusterName, unitName, node);
        namingController.registerInstance(namespace, clusterName, unitName2, node2);
        MetaResponse metaResponse = namingController.discovery(vGroup, namespace);
        assertNotNull(metaResponse);
        assertNotNull(metaResponse.getClusterList());
        assertEquals(1, metaResponse.getClusterList().size());
        Cluster cluster = metaResponse.getClusterList().get(0);
        assertNotNull(cluster.getUnitData());
        assertEquals(2, cluster.getUnitData().size());
        Unit unit = cluster.getUnitData().get(0);
        assertNotNull(unit.getNamingInstanceList());
        assertEquals(1, unit.getNamingInstanceList().size());
        namingController.unregisterInstance(namespace, clusterName, unitName, node);
        metaResponse = namingController.discovery(vGroup, namespace);
        assertNotNull(metaResponse);
        assertNotNull(metaResponse.getClusterList());
        assertEquals(1, metaResponse.getClusterList().size());
        cluster = metaResponse.getClusterList().get(0);
        assertNotNull(cluster.getUnitData());
        assertEquals(1, cluster.getUnitData().size());
        unit = cluster.getUnitData().get(0);
        assertNotNull(unit.getNamingInstanceList());
    }

    @Test
    void mockHeartbeat() throws InterruptedException {
        String clusterName = "cluster5";
        String namespace = "public5";
        String unitName = String.valueOf(UUID.randomUUID());
        String vGroup = "mockHeartbeat";
        NamingServerNode node = new NamingServerNode();
        node.setTransaction(new Node.Endpoint("127.0.0.1", 8097, "netty"));
        node.setControl(new Node.Endpoint("127.0.0.1", 7097, "http"));
        Map<String, Object> meatadata = node.getMetadata();
        Map<String, Object> vGroups = new HashMap<>();
        vGroups.put(vGroup, unitName);
        meatadata.put(CONSTANT_GROUP, vGroups);
        namingController.registerInstance(namespace, clusterName, unitName, node);
        NamingServerNode node2 = new NamingServerNode();
        node2.setTransaction(new Node.Endpoint("127.0.0.1", 8098, "netty"));
        node2.setControl(new Node.Endpoint("127.0.0.1", 7098, "http"));
        Map<String, Object> meatadata2 = node2.getMetadata();
        Map<String, Object> vGroups2 = new HashMap<>();
        String unitName2 = UUID.randomUUID().toString();
        vGroups2.put(vGroup, unitName2);
        meatadata2.put(CONSTANT_GROUP, vGroups2);
        namingController.registerInstance(namespace, clusterName, unitName2, node2);
        Thread thread = new Thread(() -> {
            for (int i = 0; i < 5; i++) {
                try {
                    TimeUnit.SECONDS.sleep(5);
                    namingController.registerInstance(namespace, clusterName, unitName, node);
                } catch (InterruptedException e) {
                    throw new RuntimeException(e);
                }
            }
        });
        thread.start();
        MetaResponse metaResponse = namingController.discovery(vGroup, namespace);
        assertNotNull(metaResponse);
        assertNotNull(metaResponse.getClusterList());
        assertEquals(1, metaResponse.getClusterList().size());
        Cluster cluster = metaResponse.getClusterList().get(0);
        assertNotNull(cluster.getUnitData());
        assertEquals(2, cluster.getUnitData().size());
        Unit unit = cluster.getUnitData().get(0);
        assertNotNull(unit.getNamingInstanceList());
        assertEquals(1, unit.getNamingInstanceList().size());
        int timeGap = threshold + period;
        Thread.sleep(timeGap);
        metaResponse = namingController.discovery(vGroup, namespace);
        assertNotNull(metaResponse);
        assertNotNull(metaResponse.getClusterList());
        assertEquals(1, metaResponse.getClusterList().get(0).getUnitData().size());
        unit = metaResponse.getClusterList().get(0).getUnitData().get(0);
        Node node1 = unit.getNamingInstanceList().get(0);
        assertEquals("127.0.0.1", node1.getTransaction().getHost());
        assertEquals(8097, node1.getTransaction().getPort());
    }

    @Test
    void testRegisterInstanceReturnMessageSuccess() {
        String clusterName = "cluster6";
        String namespace = "public6";
        String vGroup = "testRegisterInstanceReturnMessage";
        String unitName = String.valueOf(UUID.randomUUID());
        NamingServerNode node = new NamingServerNode();
        node.setTransaction(new Node.Endpoint("127.0.0.1", 8094, "netty"));
        node.setControl(new Node.Endpoint("127.0.0.1", 7094, "http"));
        Map<String, Object> meatadata = node.getMetadata();
        Map<String, Object> vGroups = new HashMap<>();
        vGroups.put(vGroup, unitName);
        meatadata.put(CONSTANT_GROUP, vGroups);
        Result<String> result = namingController.registerInstance(namespace, clusterName, unitName, node);
        assertNotNull(result);
        assertEquals("200", result.getCode());
        assertEquals("node has registered successfully!", result.getMessage());
        namingController.unregisterInstance(namespace, clusterName, unitName, node);
    }

    @Test
    void testRegisterInstanceReturnMessageFailure() {
        String clusterName = "cluster7";
        String namespace = "public7";
        String unitName = String.valueOf(UUID.randomUUID());
        NamingServerNode invalidNode = new NamingServerNode();
        Result<String> result = namingController.registerInstance(namespace, clusterName, unitName, invalidNode);
        assertNotNull(result);
        assertEquals("500", result.getCode());
        assertEquals("node registered unsuccessfully!", result.getMessage());
    }

    @Test
    void testBatchRegisterInstanceMessageSuccess() {
        String clusterName = "cluster8";
        String namespace = "public8";
        String unitName = String.valueOf(UUID.randomUUID());
        NamingServerNode node1 = new NamingServerNode();
        node1.setTransaction(new Node.Endpoint("127.0.0.1", 8097, "netty"));
        node1.setControl(new Node.Endpoint("127.0.0.1", 7097, "http"));
        node1.setUnit(unitName);
        NamingServerNode node2 = new NamingServerNode();
        node2.setTransaction(new Node.Endpoint("127.0.0.1", 8098, "netty"));
        node2.setControl(new Node.Endpoint("127.0.0.1", 7098, "http"));
        node2.setUnit(unitName);
        ArrayList<NamingServerNode> nodeList = new ArrayList<>();
        nodeList.add(node1);
        nodeList.add(node2);
        Result<String> result = namingController.batchRegisterInstance(namespace, clusterName, nodeList);
        assertNotNull(result);
        assertEquals("200", result.getCode());
        assertEquals("node has registered successfully!", result.getMessage());
    }

    @Test
    void testBatchRegisterInstanceMessageFailure() {
        String clusterName = "cluster9";
        String namespace = "public9";
        String unitName = String.valueOf(UUID.randomUUID());
        NamingServerNode node1 = new NamingServerNode();
        node1.setTransaction(new Node.Endpoint("127.0.0.1", 8097, "netty"));
        node1.setControl(new Node.Endpoint("127.0.0.1", 7097, "http"));
        node1.setUnit(unitName);
        NamingServerNode invalidNode = new NamingServerNode();
        ArrayList<NamingServerNode> nodeList = new ArrayList<>();
        nodeList.add(node1);
        nodeList.add(invalidNode);
        Result<String> result = namingController.batchRegisterInstance(namespace, clusterName, nodeList);
        assertNotNull(result);
        assertEquals("500", result.getCode());
        assertEquals("node registered unsuccessfully!", result.getMessage());
    }

    @Test
    void testAddGroupMessageSuccess() {
        String namespace = "public10";
        String clusterName = "cluster10";
        String unitName = String.valueOf(UUID.randomUUID());
        String vGroup = "testAddGroupMessageSuccess";
        NamingManager mockNamingManager = Mockito.mock(NamingManager.class);
        Result<String> expectedResult = new Result<>("200", "add vGroup successfully!");
        Mockito.when(mockNamingManager.createGroup(namespace, vGroup, clusterName, unitName)).thenReturn(expectedResult);
        try {
            Field field = NamingController.class.getDeclaredField("namingManager");
            field.setAccessible(true);
            NamingManager originalNamingManager = (NamingManager) field.get(namingController);
            field.set(namingController, mockNamingManager);
            try {
                Result<String> result = namingController.addGroup(namespace, clusterName, unitName, vGroup);
                assertNotNull(result);
                assertEquals("200", result.getCode());
                assertEquals("change vGroup " + vGroup + "to cluster " + clusterName + " successfully!", result.getMessage());
                Mockito.verify(mockNamingManager).createGroup(namespace, vGroup, clusterName, unitName);
            } finally {
                field.set(namingController, originalNamingManager);
            }
        } catch (Exception e) {
            fail("Test failed due to exception: " + e.getMessage());
        }
    }

    @Test
    void testAddGroupMessageFailure() {
        String namespace = "public11";
        String clusterName = "cluster11";
        String unitName = String.valueOf(UUID.randomUUID());
        String vGroup = "testAddGroupMessageFailure";
        NamingManager mockNamingManager = Mockito.mock(NamingManager.class);
        Result<String> expectedResult = new Result<>("500", "add vGroup in new cluster failed");
        Mockito.when(mockNamingManager.createGroup(namespace, vGroup, clusterName, unitName)).thenReturn(expectedResult);
        try {
            Field field = NamingController.class.getDeclaredField("namingManager");
            field.setAccessible(true);
            NamingManager originalNamingManager = (NamingManager) field.get(namingController);
            field.set(namingController, mockNamingManager);
            try {
                Result<String> result = namingController.addGroup(namespace, clusterName, unitName, vGroup);
                assertNotNull(result);
                assertEquals("500", result.getCode());
                assertEquals("add vGroup in new cluster failed", result.getMessage());
                Mockito.verify(mockNamingManager).createGroup(namespace, vGroup, clusterName, unitName);
            } finally {
                field.set(namingController, originalNamingManager);
            }
        } catch (Exception e) {
            fail("Test failed due to exception: " + e.getMessage());
        }
    }

}
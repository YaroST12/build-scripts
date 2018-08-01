#!/bin/bash
git fetch essential-qc3
git fetch essential-qca
git fetch essential-fw
git subtree add --prefix=drivers/staging/qcacld-3.0 essential-qc3 HEAD
git commit --am -m "staging: add qcacld-3.0 driver from Essential"
git subtree add --prefix=drivers/staging/qca-wifi-host-cmn essential-qca HEAD
git commit --am -m "staging: add qca-wifi-host-cmn driver from Essential"
git subtree add --prefix=drivers/staging/fw-api essential-fw HEAD
git commit --am -m "staging: add fw-api from Essential"
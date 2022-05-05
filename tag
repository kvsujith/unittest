import random

import pytest
import requests
from unit_test import BASE_URL

from ..tag import expected_create_response, expected_update_response
from ..utils.utils import dict_contains

create_payloads = []


@pytest.fixture(scope="module")
def setup():
    global create_payloads
    create_payloads = [
        {
            "type": random.randint(1, 2),
            "name": f"Item {i + 1}"
        } for i in range(20)
    ]
    yield


def test_create_tag_white_box(setup):
    global create_payloads
    for payload in create_payloads:
        resp = requests.post(url=f"{BASE_URL}/tag", json=payload)
        assert 201 == resp.status_code
        resp = resp.json()
        expected_create_response["result"]["id"] = resp["result"]["id"]
        payload.update({"id": resp["result"]["id"], "created_by": "admin", "modified_by": None})
        assert resp == expected_create_response


@pytest.mark.depends(on=['test_create_tag_white_box'])
def test_no_of_item_created(setup):
    resp = requests.get(url=f"{BASE_URL}/tag")
    assert 200 == resp.status_code
    assert len(create_payloads) == len(resp.json())


@pytest.mark.depends(on=['test_create_tag_white_box'])
def test_get_tag_by_id(setup):
    for item in create_payloads:
        resp = requests.get(url=f"{BASE_URL}/tag/{item['id']}")
        assert 200 == resp.status_code
        resp = resp.json()
        assert dict_contains(item, resp)


@pytest.mark.depends(on=['test_no_of_item_created'])
def test_creating_duplicate_tags(setup):
    for payload in create_payloads:
        item = dict({
            "name": payload["name"],
            "type": payload["type"],
        })
        resp = requests.post(url=f"{BASE_URL}/tag", json=item)
        assert 400 == resp.status_code
        resp = resp.json()
        assert resp == {"error": f"Tag name '{item['name']}' already exists. "}


@pytest.mark.depends(on=['test_no_of_item_created'])
def test_create_tag_with_empty_name(setup):
    for payload in create_payloads:
        item = dict(
            {
                'name': "",
                'type': payload["type"]
            }
        )

        resp = requests.post(url=f"{BASE_URL}/tag", json=item)
        assert 400 == resp.status_code
        assert {"status": True,
                "message": "Tag name field cannot be null"
                } == resp.json()


@pytest.mark.depends(on=['test_no_of_item_created'])
def test_create_tag_without_name(setup):
    for payload in create_payloads:
        item = dict({
            "type": payload["type"],
        })
        resp = requests.post(url=f"{BASE_URL}/tag", json=item)
        assert 400 == resp.status_code

        assert {"errors": {
            "name": "'name' is a required property"
        },
                   "message": "Input payload validation failed"
               } == resp.json()


@pytest.mark.depends(on=['test_no_of_item_created'])
def test_create_tag_without_type(setup):
    for payload in create_payloads:
        item = dict({
            "name": payload["name"]
        })
        resp = requests.post(url=f"{BASE_URL}/tag", json=item)
        assert 400 == resp.status_code
        assert {
                   "errors": {
                       "type": "'type' is a required property"
                   },
                   "message": "Input payload validation failed"
               } == resp.json()


@pytest.mark.depends(on=['test_no_of_item_created'])
def test_create_tag_with_invalid_type(setup):
    for payload in create_payloads:
        item = dict({
            "type": random.randint(4, 19),
            "name": f"Item {random.randint(22, 49)}"
        })
        resp = requests.post(url=f"{BASE_URL}/tag", json=item)
        assert 400 == resp.status_code
        assert {
                   "error": f"{item['type']} is not a valid TagType"
               } == resp.json()


@pytest.mark.depends(on=['test_no_of_item_created'])
def test_update_tag_with_non_exists_name(setup):
    for payload in create_payloads:
        item = dict({
            "name": f"New Name {payload['id']}"
        })
        resp = requests.put(url=f"{BASE_URL}/tag/update/{payload['id']}", json=item)
        assert 200 == resp.status_code
        resp = resp.json()
        expected_update_response["result"]["id"] = resp["result"]["id"]
        assert expected_update_response == resp


@pytest.mark.depends(on=['test_update_tag_with_non_exists_name'])
def test_update_tag_with_duplicate_exists_name(setup):
    for payload in range(1, len(create_payloads)):
        item = dict({
            "name": f"New Name {create_payloads[payload - 1]['id']}"
        })
        resp = requests.put(url=f"{BASE_URL}/tag/update/{create_payloads[payload]['id']}", json=item)
        assert 400 == resp.status_code
        resp = resp.json()
        assert {'error': f"Tag name 'New Name {create_payloads[payload]['id'] - 1}' already exists. "} == resp


@pytest.mark.depends(on=['test_no_of_item_created'])
def test_update_tag_with_invalid_type(setup):
    for payload in create_payloads:
        item = dict({
            "type": random.randint(22, 49)
        })
        resp = requests.put(url=f"{BASE_URL}/tag/update/{payload['id']}", json=item)
        assert 400 == resp.status_code
        assert {
                   "error": f"{item['type']} is not a valid TagType"
               } == resp.json()


@pytest.mark.depends(on=['test_update_tag_with_invalid_type'])
def test_delete_tag(setup):
    for payload in create_payloads:
        resp = requests.delete(url=f"{BASE_URL}/tag/delete/{payload['id']}")
        assert 204 == resp.status_code


@pytest.mark.depends(on=['test_delete_tag'])
def test_access_deleted_tags(setup):
    for payload in create_payloads:
        resp = requests.get(url=f"{BASE_URL}/tag/{payload['id']}")
        assert 400 == resp.status_code
        assert {
                   "error": "No resource found"
               } == resp.json()


@pytest.mark.depends(on=['test_delete_tag'])
def test_update_deleted_tag(setup):
    for payload in create_payloads:
        item = dict({
            "name": f"New Name {payload['id']}"
        })
        resp = requests.put(url=f"{BASE_URL}/tag/update/{payload['id']}", json=item)
        assert 400 == resp.status_code
        assert {
                   "error": "No resource found"
               } == resp.json()

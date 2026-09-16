import uuid

from locust import HttpUser, between, task


class CompanyCheckUser(HttpUser):
    wait_time = between(0.2, 0.8)

    @task(4)
    def check_company(self):
        self.client.get(
            "/backend-service",
            params={"verificationId": str(uuid.uuid4()), "query": "Acme"},
            name="GET /backend-service",
        )

    @task(1)
    def read_unknown_verification(self):
        self.client.get(f"/verifications/{uuid.uuid4()}", name="GET /verifications/{verificationId}")

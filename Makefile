.PHONY: help \
	backend-up backend-up-detached backend-down backend-restart backend-build backend-logs backend-ps \
	migrate migrate-status migrate-down migrate-reset db-shell db-reset \
	api-health api-spaces api-nearby \
	nuc-up nuc-down nuc-logs nuc-smoke nuc-rollback \
	ios-build ios-run ios-simulators

BACKEND_DIR := backend
IOS_DIR := ios-invisible-museum
IOS_PROJECT := InvisibleMuseum.xcodeproj
IOS_SCHEME := InvisibleMuseum
IOS_BUNDLE_ID := com.rork.InvisibleMuseum
IOS_BUILD_DIR := build
SIMULATOR_ID ?= 46977DDD-8007-4137-AA70-C106917A7DB7
NEARBY_LAT ?= 41.794
NEARBY_LNG ?= -88.007
NEARBY_RADIUS_M ?= 5000

help:
	@printf "Invisible Museum commands\n\n"
	@printf "Backend:\n"
	@printf "  make backend-up           Start API/Postgres in foreground\n"
	@printf "  make backend-up-detached  Start API/Postgres in background\n"
	@printf "  make backend-down         Stop backend stack\n"
	@printf "  make backend-build        Build backend API image\n"
	@printf "  make backend-logs         Follow backend logs\n"
	@printf "  make backend-ps           Show backend containers\n\n"
	@printf "Migrations / DB:\n"
	@printf "  make migrate              Run goose migrations up\n"
	@printf "  make migrate-status       Show goose migration status\n"
	@printf "  make migrate-down         Roll back one migration\n"
	@printf "  make migrate-reset        Roll back all, then migrate up\n"
	@printf "  make db-shell             Open psql shell\n"
	@printf "  make db-reset             Delete Postgres volume and recreate stack\n\n"
	@printf "API smoke tests:\n"
	@printf "  make api-health           Curl /healthz\n"
	@printf "  make api-spaces           Curl /api/v1/spaces\n"
	@printf "  make api-nearby           Curl nearby Downers Grove spaces\n\n"
	@printf "NUC / Almaz deployment:\n"
	@printf "  make nuc-up               Start deployment stack\n"
	@printf "  make nuc-down             Stop deployment stack\n"
	@printf "  make nuc-logs             Follow deployment logs\n"
	@printf "  make nuc-smoke            Health + moderation smoke checks\n"
	@printf "  make nuc-rollback         Goose rollback one migration\n\n"
	@printf "iOS:\n"
	@printf "  make ios-build            Build iOS app for simulator\n"
	@printf "  make ios-run              Boot/install/launch on SIMULATOR_ID\n"
	@printf "  make ios-simulators       List available simulators\n"

backend-up:
	cd $(BACKEND_DIR) && docker compose up --build

backend-up-detached:
	cd $(BACKEND_DIR) && docker compose up --build -d

backend-down:
	cd $(BACKEND_DIR) && docker compose down

backend-restart: backend-down backend-up-detached

backend-build:
	cd $(BACKEND_DIR) && docker compose build api

backend-logs:
	cd $(BACKEND_DIR) && docker compose logs -f

backend-ps:
	cd $(BACKEND_DIR) && docker compose ps

migrate:
	cd $(BACKEND_DIR) && docker compose run --rm migrate

migrate-status:
	cd $(BACKEND_DIR) && docker compose run --rm migrate goose -dir /migrations status

migrate-down:
	cd $(BACKEND_DIR) && docker compose run --rm migrate goose -dir /migrations down

migrate-reset:
	cd $(BACKEND_DIR) && docker compose run --rm migrate goose -dir /migrations reset && docker compose run --rm migrate

db-shell:
	cd $(BACKEND_DIR) && docker compose exec postgres psql -U museum -d invisible_museum

db-reset:
	cd $(BACKEND_DIR) && docker compose down -v && docker compose up --build -d

api-health:
	curl http://localhost:8080/healthz

api-spaces:
	curl http://localhost:8080/api/v1/spaces

api-nearby:
	curl "http://localhost:8080/api/v1/spaces/nearby?lat=$(NEARBY_LAT)&lng=$(NEARBY_LNG)&radius_m=$(NEARBY_RADIUS_M)"

NUC_COMPOSE := -f backend/docker-compose.nuc.yml
NUC_API_URL ?= http://localhost:8080
ADMIN_BEARER_TOKEN ?= dev-admin-token

nuc-up:
	docker compose $(NUC_COMPOSE) up --build -d

nuc-down:
	docker compose $(NUC_COMPOSE) down

nuc-logs:
	docker compose $(NUC_COMPOSE) logs -f

nuc-smoke:
	curl "$(NUC_API_URL)/healthz" && curl -H "Authorization: Bearer $(ADMIN_BEARER_TOKEN)" "$(NUC_API_URL)/api/v1/admin/contributions?status=pending"

nuc-rollback:
	docker compose $(NUC_COMPOSE) run --rm migrate goose -dir /migrations down

ios-build:
	cd $(IOS_DIR) && xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" -destination 'platform=iOS Simulator,id=$(SIMULATOR_ID)' SYMROOT="$(IOS_BUILD_DIR)" build

ios-run: ios-build
	xcrun simctl boot "$(SIMULATOR_ID)" || true
	open -a Simulator
	xcrun simctl install "$(SIMULATOR_ID)" "$(IOS_DIR)/$(IOS_BUILD_DIR)/Debug-iphonesimulator/InvisibleMuseum.app"
	xcrun simctl launch "$(SIMULATOR_ID)" "$(IOS_BUNDLE_ID)"

ios-simulators:
	xcrun simctl list devices available

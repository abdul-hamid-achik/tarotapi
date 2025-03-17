# tarot api

rails api for tarot card readings and interpretations

## requirements

- docker and docker compose v2.22.0+ (required)
- make (optional, for running tasks)

## quick start

```bash
# clone repository and enter directory
git clone <repository-url> && cd tarot_api

# copy environment file
cp .env.example .env

# setup development environment
rake dev:setup

# start development with file watching
rake docker:watch
```

## development commands

all commands run inside docker containers automatically.

### core tasks
```bash
rake dev:setup      # setup development environment
rake dev:reset      # reset development environment
rake dev:test       # run tests
rake dev:lint       # run rubocop
rake dev:console    # start rails console
```

### documentation
```bash
rake docs:generate  # generate api documentation
```

### docker management
```bash
rake docker:watch   # start development with file watching
rake docker:rebuild # rebuild and restart environment
rake docker:logs    # view container logs
rake docker:ssh     # ssh into api container
```

### direct docker compose commands
```bash
docker compose up     # start containers
docker compose down   # stop containers
docker compose build  # rebuild containers
```

## development workflow

1. initial setup:
   ```bash
   git clone <repository-url>
   cd tarot_api
   cp .env.example .env
   rake dev:setup
   ```

2. start development:
   ```bash
   rake docker:watch
   ```

3. common development tasks:
   ```bash
   rake dev:console  # start rails console
   rake dev:test     # run tests
   rake dev:lint     # run linter
   rake docker:logs  # view logs
   ```

4. making changes:
   - edit files - changes sync automatically
   - new gems - changes trigger container restart
   - database changes:
     ```bash
     rake dev:reset  # reset database
     ```
   - documentation updates:
     ```bash
     rake docs:generate
     ```

## api documentation

- swagger ui: http://localhost:3000/docs
- openapi spec: http://localhost:3000/api/v1/swagger.yaml

## project structure

```
.
├── app/            # application code
│   ├── controllers/  # api endpoints
│   ├── models/       # database models
│   └── services/     # business logic
├── config/         # configuration files
├── db/            # database files
│   ├── migrate/     # database migrations
│   └── seeds/       # seed data
├── lib/           # library code
│   └── tasks/       # rake tasks
├── spec/          # tests
└── public/        # public assets
    ├── docs/       # swagger ui
    └── api/        # openapi specs
```

## troubleshooting

1. reset everything:
   ```bash
   rake docker:rebuild  # rebuilds all containers
   rake dev:reset      # resets database
   ```

2. view logs:
   ```bash
   rake docker:logs
   ```

3. access container shell:
   ```bash
   rake docker:ssh
   ```

## contributing

1. fork the repository
2. create your feature branch
3. commit your changes
4. push to the branch
5. create a pull request

## license

[mit](license)

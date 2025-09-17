#!/bin/bash

# Development environment manager

# Default configuration - can be overridden by environment variables
DEFAULT_COMPOSE_FILE="${COMPOSE_FILE:-compose.dev.yaml}"
DEFAULT_ENV_FILE="${ENV_FILE:-../../catapult/.env}"

show_help() {
    echo "Usage: ./dev.sh [command] [flags]"
    echo ""
    echo "Environment commands:"
    echo "  start [--mysql] [--postgres] [--redis] [--no-recreate] [-f compose-file] [--env-file env-file] - Start development environment"
    echo "    Examples:"
    echo "      ./dev.sh start                       # MySQL only (default)"
    echo "      ./dev.sh start --mysql --redis       # MySQL + Redis"
    echo "      ./dev.sh start --postgres --redis    # PostgreSQL + Redis"
    echo "      ./dev.sh start --mysql --postgres    # Both databases"
    echo "      ./dev.sh start --postgres            # PostgreSQL only"
    echo "      ./dev.sh start --redis               # Redis only"
    echo "      ./dev.sh start --no-recreate         # Don't recreate containers"
    echo "      ./dev.sh start -f custom.yaml        # Use custom compose file"
    echo "      ./dev.sh start --env-file .env.local # Use custom env file"
    echo ""
    echo "  stop [-v] [-f compose-file]     - Stop containers (-v removes volumes)"
    echo "  restart       - Restart development environment"
    echo "  logs          - Show container logs"
    echo ""
    echo "Development commands:"
    echo "  composer      - Run composer install"
    echo "  artisan [cmd] - Run artisan commands"
    echo "  npm [cmd]     - Run npm commands"
    echo ""
    echo "Database commands:"
    echo "  mysql         - Connect to MySQL"
    echo "  postgres      - Connect to PostgreSQL"
    echo "  redis         - Connect to Redis"
    echo ""
    echo "Utility commands:"
    echo "  build         - Rebuild containers"
    echo "  clean         - Stop and remove all containers/volumes"
    echo "  destroy       - Nuclear option: stop, remove containers, volumes, networks, images"
    echo "  shell         - Open shell in app container"
}

parse_start_flags() {
    local profiles=""
    local compose_flags=""
    local compose_file="$DEFAULT_COMPOSE_FILE"
    local env_file="--env-file $DEFAULT_ENV_FILE"

    # Start with no services (explicit opt-in)
    local use_mysql=false
    local use_postgres=false
    local use_redis=false

    shift # Remove 'start' command

    # If no flags provided, default to MySQL
    if [[ $# -eq 0 ]]; then
        use_mysql=true
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --mysql)
                use_mysql=true
                shift
                ;;
            --postgres)
                use_postgres=true
                shift
                ;;
            --redis)
                use_redis=true
                shift
                ;;
            --no-recreate)
                compose_flags="$compose_flags --no-recreate"
                shift
                ;;
            -f)
                if [[ -n "$2" ]]; then
                    compose_file="$2"
                    shift 2
                else
                    echo "Error: -f requires a compose file argument"
                    exit 1
                fi
                ;;
            --env-file)
                if [[ -n "$2" ]]; then
                    env_file="--env-file $2"
                    shift 2
                else
                    echo "Error: --env-file requires a file argument"
                    exit 1
                fi
                ;;
            *)
                echo "Unknown flag: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Build profiles
    if [[ "$use_mysql" == true ]]; then
        profiles="$profiles --profile mysql"
    fi
    if [[ "$use_postgres" == true ]]; then
        profiles="$profiles --profile postgres"
    fi
    if [[ "$use_redis" == true ]]; then
        profiles="$profiles --profile redis"
    fi

    echo "-f $compose_file $env_file $profiles$compose_flags"
}

case "$1" in
    start)
        flags=$(parse_start_flags "$@")
        docker compose $flags up -d
        ;;
    stop)
        compose_file="$DEFAULT_COMPOSE_FILE"
        env_file="--env-file $DEFAULT_ENV_FILE"
        # Parse flags for stop command
        shift
        while [[ $# -gt 0 ]]; do
            case $1 in
                -v)
                    volume_flag="-v"
                    shift
                    ;;
                -f)
                    if [[ -n "$2" ]]; then
                        compose_file="$2"
                        shift 2
                    else
                        echo "Error: -f requires a compose file argument"
                        exit 1
                    fi
                    ;;
                *)
                    echo "Unknown flag for stop: $1"
                    show_help
                    exit 1
                    ;;
            esac
        done
        docker compose -f "$compose_file" $env_file down $volume_flag
        ;;
    restart)
        docker compose -f compose.dev.yaml down
        docker compose -f compose.dev.yaml --profile mysql --profile redis up -d
        ;;
    logs)
        compose_file="$DEFAULT_COMPOSE_FILE"
        env_file="--env-file $DEFAULT_ENV_FILE"
        shift
        # Parse flags for logs command
        while [[ $# -gt 0 ]]; do
            case $1 in
                -f)
                    if [[ -n "$2" ]]; then
                        compose_file="$2"
                        shift 2
                    else
                        echo "Error: -f requires a compose file argument"
                        exit 1
                    fi
                    ;;
                --env-file)
                    if [[ -n "$2" ]]; then
                        env_file="--env-file $2"
                        shift 2
                    else
                        echo "Error: --env-file requires a file argument"
                        exit 1
                    fi
                    ;;
                *)
                    shift
                    ;;
            esac
        done
        docker compose -f "$compose_file" $env_file logs -f
        ;;
    composer)
        shift
        # Default to install if no arguments provided
        if [[ $# -eq 0 ]]; then
            docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" exec app composer install
        else
            docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" exec app composer "$@"
        fi
        ;;
    artisan)
        shift
        docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" exec app php artisan "$@"
        ;;
    npm)
        shift
        docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" exec app npm "$@"
        ;;
    mysql)
        docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" exec mysql mysql -u root -p
        ;;
    postgres)
        docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" exec postgres psql -U ${DB_USERNAME:-laravel} -d ${DB_DATABASE:-laravel}
        ;;
    redis)
        docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" exec redis redis-cli
        ;;
    build)
        docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" build --no-cache
        ;;
    clean)
        docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" down -v
        ;;
    destroy)
        echo "🚨 WARNING: This will completely destroy all containers, volumes, networks, and images!"
        echo "This action cannot be undone."
        read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirmation

        if [[ "$confirmation" == "yes" ]]; then
            echo "🔥 Destroying everything..."

            # Stop and remove everything from the compose file
            docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" down -v --remove-orphans

            # Remove all related images
            echo "🗑️  Removing images..."
            docker images | grep -E "(laravel|mysql|postgres|redis)" | awk '{print $3}' | xargs -r docker rmi -f

            # Remove dangling volumes
            echo "🗑️  Removing dangling volumes..."
            docker volume prune -f

            # Remove unused networks
            echo "🗑️  Removing unused networks..."
            docker network prune -f

            # Optional: Clean up dangling images
            echo "🗑️  Removing dangling images..."
            docker image prune -f

            echo "✅ Destruction complete! Everything has been removed."
        else
            echo "❌ Operation cancelled."
        fi
        ;;
    shell)
        docker compose -f "$DEFAULT_COMPOSE_FILE" --env-file "$DEFAULT_ENV_FILE" exec app bash
        ;;
    *)
        show_help
        ;;
esac
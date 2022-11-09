import subprocess
import typer
import requests


def get_latest_snapshot():
    """Get the latest snapshot URL"""
    return requests.get(
        "https://snapshots.mainnet.filops.net/minimal/latest",
        allow_redirects=False,
        timeout=10,
    ).headers["Location"]


def download(url: str, folder: str = "."):
    """Download a file from URL"""
    print(f"Downloading {url} to {folder}")
    subprocess.run(
        ["aria2c", "-x16", "-s16", url, "-d", folder, "--log-level", "notice"],
        check=True,
    )


def etl(car_file: str = typer.Argument(default="latest", help="CAR file to process")):
    """Download the latest snapshot"""
    if car_file == "latest":
        url = get_latest_snapshot()
        # download(url)
        print(f"Processing {url}")
    elif car_file.startswith("http"):
        download(car_file)
    else:
        print(f"Processing {car_file}")

    # Run lily init
    subprocess.run(["lily", "init"], check=True)


def app():
    typer.run(etl)


if __name__ == "__main__":
    app()

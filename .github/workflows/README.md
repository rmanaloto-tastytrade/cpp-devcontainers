# Workflows Documentation  

This folder contains GitHub Actions workflows for the SlotMap project. The workflows automate tasks such as building the devcontainer image and (optionally) running tests.  

## build-devcontainer.yml  

This workflow builds and publishes the devcontainer Docker image used by the project. It runs on a self-hosted runner labelled `self-hosted` and `devcontainer-builder`. The steps are:  

- Checkout the repository.  
- Set up Docker Buildx for building multi-platform images.  
- Log in to GitHub Container Registry (GHCR) using the `GITHUB_TOKEN`.  
- Build the devcontainer image from `.devcontainer/Dockerfile` and push it to GHCR.  

### Trigger  

- Automatically runs on pushes to the `main` branch.  
- Can also be run manually using the *Run workflow* button in the Actions tab.  

## Adding More Workflows  

You can add other workflows to automate linting, testing, or deployment. For consistency between local development and CI, try to run your jobs inside the devcontainer image built by `build-devcontainer.yml`.

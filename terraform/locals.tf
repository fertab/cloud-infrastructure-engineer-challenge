locals {
  name = "info"
  azs  = ["us-east-2a", "us-east-2b"]

  public_cidrs   = ["10.42.0.0/24", "10.42.1.0/24"]
  private_cidrs  = ["10.42.10.0/24", "10.42.11.0/24"]
  isolated_cidrs = ["10.42.20.0/24", "10.42.21.0/24"]
}

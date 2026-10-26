using Microsoft.EntityFrameworkCore;

namespace Toni.Api.Data;

public class ToniDb(DbContextOptions<ToniDb> options) : DbContext(options)
{
    public DbSet<Person> People => Set<Person>();
    public DbSet<Period> Periods => Set<Period>();
    public DbSet<Strike> Strikes => Set<Strike>();
    public DbSet<Vote> Votes => Set<Vote>();
    public DbSet<Ballot> Ballots => Set<Ballot>();
    public DbSet<User> Users => Set<User>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<Person>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(60);
            e.Property(x => x.Color).HasMaxLength(9);
        });

        b.Entity<Period>(e =>
        {
            e.Property(x => x.Type).HasMaxLength(16);
            e.Property(x => x.Label).HasMaxLength(80);
        });

        // Deleting a person or period removes everything that hangs off it.
        b.Entity<Strike>(e =>
        {
            e.Property(x => x.Reason).HasMaxLength(140);
            e.Property(x => x.Source).HasMaxLength(16);
            e.HasOne<Person>().WithMany().HasForeignKey(x => x.PersonId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne<Period>().WithMany().HasForeignKey(x => x.PeriodId).OnDelete(DeleteBehavior.Cascade);
            e.HasIndex(x => x.PeriodId);
        });

        b.Entity<Vote>(e =>
        {
            e.Property(x => x.Reason).HasMaxLength(140);
            e.Property(x => x.Status).HasMaxLength(16);
            e.HasOne<Person>().WithMany().HasForeignKey(x => x.PersonId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne<Period>().WithMany().HasForeignKey(x => x.PeriodId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne<Person>().WithMany().HasForeignKey(x => x.CreatedBy).OnDelete(DeleteBehavior.SetNull);
            e.HasMany(x => x.Ballots).WithOne().HasForeignKey(x => x.VoteId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<Ballot>(e =>
        {
            e.HasKey(x => new { x.VoteId, x.PersonId });
            e.Property(x => x.Choice).HasMaxLength(8);
            e.HasOne<Person>().WithMany().HasForeignKey(x => x.PersonId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<User>(e =>
        {
            e.Property(x => x.Username).HasMaxLength(40);
            e.Property(x => x.Role).HasMaxLength(16);
            e.HasIndex(x => x.Username).IsUnique();
            e.HasOne<Person>().WithMany().HasForeignKey(x => x.PersonId).OnDelete(DeleteBehavior.Cascade);
        });
    }
}

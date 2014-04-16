#import <Kiwi/Kiwi.h>
#import <ObjectiveSugar/ObjectiveSugar.h>

#import <ObjectiveRecord/ObjectiveRecord.h>

#import "Car+Mappings.h"
#import "OBRPerson.h"
#import "Person+Mappings.h"

static NSString *UNIQUE_NAME = @"ldkhbfaewlfbaewljfhb";
static NSString *UNIQUE_SURNAME = @"laewfbaweljfbawlieufbawef";

#pragma mark - Helpers

Person *fetchUniquePerson() {
    return [Person find:@"firstName = %@ AND lastName = %@", UNIQUE_NAME, UNIQUE_SURNAME];
}

NSManagedObjectContext *createNewContext() {
    NSManagedObjectContext *newContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    newContext.persistentStoreCoordinator = [[CoreDataManager sharedManager] persistentStoreCoordinator];
    return newContext;
}

void createSomePeople(NSArray *names, NSArray *surnames, NSManagedObjectContext *context) {
    for (int i = 0; i < names.count; i++) {
        Person *person = [[Person inContext:context] create];
        person.firstName = names[i];
        person.lastName = surnames[i];
        person.age = @(i);
        person.isMember = @YES;
        person.anniversary = [NSDate dateWithTimeIntervalSince1970:0];
        [person save];
    }
}

SPEC_BEGIN(FindersAndCreators)

describe(@"Find / Create / Save / Delete specs", ^{

    NSArray *names = @[@"John", @"Steve", @"Neo", UNIQUE_NAME];
    NSArray *surnames = @[@"Doe", @"Jobs", @"Anderson", UNIQUE_SURNAME];

    beforeEach(^{
        [Person deleteAll];
        createSomePeople(names, surnames, NSManagedObjectContext.defaultContext);
    });

    context(@"Finders", ^{

        it(@"Finds ALL the entities!", ^{
            [[[Person all] should] haveCountOf:[names count]];
        });

        it(@"Finds using [Entity where: STRING]", ^{

            Person *unique = [[Person where:[NSString stringWithFormat:@"firstName == '%@'",UNIQUE_NAME]] firstObject];
            [[unique.lastName should] equal:UNIQUE_SURNAME];

        });

        it(@"Finds using [Entity where: STRING and ARGUMENTS]", ^{

            Person *unique = [[Person where:@"firstName == %@", UNIQUE_NAME] firstObject];
            [[unique.lastName should] equal:UNIQUE_SURNAME];

        });

        it(@"Finds using [Entity where: DICTIONARY]", ^{
            Person *person = [[Person where:@{
                @"firstName": @"John",
                @"lastName": @"Doe",
                @"age": @0,
                @"isMember": @1,
                @"anniversary": [NSDate dateWithTimeIntervalSince1970:0]
            }] firstObject];

            [[person.firstName should] equal:@"John"];
            [[person.lastName should] equal:@"Doe"];
            [[person.age should] equal:@0];
            [[person.isMember should] equal:@(YES)];
            [[person.anniversary should] equal:[NSDate dateWithTimeIntervalSince1970:0]];
        });

        it(@"Finds using chained wheres", ^{
            CoreDataRelation *query = [[[[[[Person where:@{@"firstName": @"John"}] where:@{@"lastName": @"Doe"}] where:@{@"lastName": @"Doe"}] where:@{@"age": @0}] where:@{@"isMember": @YES}] where:@{@"anniversary": [NSDate dateWithTimeIntervalSince1970:0] }];

            Person *person = [query firstObject];
            [[person.firstName should] equal:@"John"];
            [[person.lastName should] equal:@"Doe"];
            [[person.age should] equal:@0];
            [[person.isMember should] equal:theValue(YES)];
            [[person.anniversary should] equal:[NSDate dateWithTimeIntervalSince1970:0]];

            [[@([[query where:@"firstName = 'Stephen'"]count]) should] equal:@0];
        });

        it(@"Finds and creates if there was no object", ^{
            [Person deleteAll];
            Person *luis = [Person findOrCreate:@{ @"firstName": @"Luis" }];
            [[luis.firstName should] equal:@"Luis"];
        });

        it(@"doesn't create duplicate objects on findOrCreate", ^{
            [Person deleteAll];
            [@4 times:^{
                [Person findOrCreate:@{ @"firstName": @"Luis" }];
            }];
            [[[Person all] should] haveCountOf:1];
        });

        it(@"Finds the first match", ^{
            Person *johnDoe = [Person find:@{ @"firstName": @"John",
                                              @"lastName": @"Doe" }];
            [[johnDoe.firstName should] equal:@"John"];
        });

        it(@"Finds the first match using [Entity find: STRING]", ^{
            Person *johnDoe = [Person find:@"firstName = 'John' AND lastName = 'Doe'"];
            [[johnDoe.firstName should] equal:@"John"];
        });

        it(@"Finds the first match using [Entity find: STRING and ARGUMENTS]", ^{
            Person *johnDoe = [Person find:@"firstName = %@ AND lastName = %@", @"John", @"Doe"];
            [[johnDoe.firstName should] equal:@"John"];
        });

        it(@"doesn't create an object on find", ^{
            Person *cat = [Person find:@{ @"firstName": @"Cat" }];
            [cat shouldBeNil];
        });

        it(@"Finds a limited number of results", ^{
            [@4 times:^{
                Person *newPerson = [Person create];
                newPerson.firstName = @"John";
                [newPerson save];
            }];
            [[[[Person where:@{ @"firstName": @"John" }] limit:2] should] haveCountOf:2];
        });
    });

    describe(@"Ordering, offseting, and grouping", ^{

        id (^firstNameMapper)(Person *) = ^id (Person *p) { return p.firstName; };
        id (^lastNameMapper)(Person *) = ^id (Person *p) { return p.lastName; };

        beforeEach(^{
            [Person deleteAll];
            createSomePeople(@[@"Abe", @"Bob", @"Cal", @"Don"],
                             @[@"Zed", @"Mol", @"Gaz", @"Mol"],
                             [NSManagedObjectContext defaultContext]);
        });

        it(@"orders results by a single property", ^{
            NSArray *resultLastNames = [[Person order:@"lastName"].fetchedObjects
                                        map:lastNameMapper];
            [[resultLastNames should] equal:@[@"Gaz", @"Mol", @"Mol", @"Zed"]];
        });

        it(@"orders results by a single string property descending", ^{
            NSArray *resultFirstNames = [[Person order:@"firstName DESC"].fetchedObjects
                                         map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Don", @"Cal", @"Bob", @"Abe"]];
        });

        it(@"orders results by multiple string properties descending", ^{
            NSArray *resultFirstNames = [[Person order:@"lastName, firstName DESC"].fetchedObjects
                                         map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Cal", @"Don", @"Bob", @"Abe"]];
        });

        it(@"orders results by multiple properties", ^{
            NSArray *resultFirstNames = [[Person order:@[@"lastName", @"firstName"]].fetchedObjects
                                         map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Cal", @"Bob", @"Don", @"Abe"]];
        });

        it(@"orders results by chained properties", ^{
            NSArray *resultFirstNames = [[[Person order:@"lastName"] order:@"firstName"].fetchedObjects
                                         map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Cal", @"Bob", @"Don", @"Abe"]];
        });

        it(@"orders results by property ascending", ^{
            NSArray *resultFirstNames = [[Person order:@{@"firstName" : @"ASC"}].fetchedObjects
                                         map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Abe", @"Bob", @"Cal", @"Don"]];
        });

        it(@"orders results by property descending", ^{
            NSArray *resultFirstNames = [[Person order:@[@{@"firstName" : @"DESC"}]].fetchedObjects
                                         map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Don", @"Cal", @"Bob", @"Abe"]];
        });

        it(@"orders results by sort descriptors", ^{
            NSArray *resultFirstNames = [[Person order:@[[NSSortDescriptor sortDescriptorWithKey:@"lastName" ascending:YES],
                                                         [NSSortDescriptor sortDescriptorWithKey:@"firstName" ascending:NO]]].fetchedObjects
                                         map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Cal", @"Don", @"Bob", @"Abe"]];
        });

        it(@"orders found results", ^{
            NSArray *resultFirstNames = [[[Person where:@{@"lastName" : @"Mol"}] order:@"firstName"].fetchedObjects
                                         map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Bob", @"Don"]];
        });

        it(@"reorders results", ^{
            NSArray *resultFirstNames = [[[Person order:@"firstName ASC"] reorder:@"firstName DESC"].fetchedObjects
                                         map:firstNameMapper];

            [[resultFirstNames should] equal:@[@"Don", @"Cal", @"Bob", @"Abe"]];
        });

        it(@"orders limited results", ^{
            NSArray *resultLastNames = [[[Person order:@"lastName"] limit:2].fetchedObjects
                                        map:lastNameMapper];
            [[resultLastNames should] equal:@[@"Gaz", @"Mol"]];
        });

        it(@"orders found and limited results", ^{
            NSArray *resultFirstNames = [[[[Person where:@{@"lastName" : @"Mol"}]
                                                 order:@[@{@"lastName" : @"ASC"},
                                                         @{@"firstName" : @"DESC"}]]
                                                 limit:1].fetchedObjects
                                         map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Don"]];
        });

        it(@"reverses order", ^{
            NSArray *resultLastNames = [[[Person order:@"lastName"] reverseOrder].fetchedObjects
                                        map:lastNameMapper];
            [[resultLastNames should] equal:@[@"Zed", @"Mol", @"Mol", @"Gaz"]];
        });

        it(@"offsets found results", ^{
            NSArray *resultLastNames = [[[Person order:@"lastName"] offset:1].fetchedObjects
                                        map:lastNameMapper];
            [[resultLastNames should] equal:@[@"Mol", @"Mol", @"Zed"]];
        });

        it(@"respects default order", ^{
            [Person stub:@selector(defaultOrder) andReturn:@"lastName ASC, firstName ASC"];
            NSArray *resultFirstNames = [[Person all].fetchedObjects
                                         map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Cal", @"Bob", @"Don", @"Abe"]];

            [Person stub:@selector(defaultOrder) andReturn:@"lastName DESC, firstName DESC"];
            resultFirstNames = [[Person all].fetchedObjects
                                map:firstNameMapper];
            [[resultFirstNames should] equal:@[@"Abe", @"Don", @"Bob", @"Cal"]];
        });

        it(@"groups entities into sections", ^{
            NSArray *people = [[Person order:@"lastName, firstName"] group:@"lastName"].fetchedObjects;
            [[[people should] have:3] sections];
            NSArray *mols = people[1];
            [[[mols valueForKey:@"lastName"] should] equal:@[@"Mol", @"Mol"]];
            [[[mols should] have:2] values];
        });

    });

    context(@"Counting", ^{

        it(@"counts all entities", ^{
            [[@([Person count]) should] equal:@(4)];
        });

        it(@"counts found entities", ^{
            NSUInteger count = [[Person where:@{@"firstName" : @"Neo"}] count];
            [[@(count) should] equal:@(1)];
        });

        it(@"counts zero when none found", ^{
            NSUInteger count = [[Person where:@{@"firstName" : @"Nobody"}] count];
            [[@(count) should] equal:@(0)];
        });

        it(@"any returns true when any are found", ^{
            [[@([Person any]) should] beTrue];
        });

        it(@"any returns false when none are found", ^{
            [[@([[Person where:@"firstName = 'Nobody'"] any]) should] beFalse];
        });

    });

    context(@"Creating", ^{

        it(@"creates without arguments", ^{
            Person *person = [Person create];
            person.firstName = @"marin";
            person.lastName = UNIQUE_SURNAME;
            [[[[[Person where:@"firstName == 'marin'"] firstObject] lastName] should] equal:UNIQUE_SURNAME];
        });


        it(@"creates with dict", ^{
            Person *person = [Person create:@{
                @"firstName": @"Marin",
                @"lastName": @"Usalj",
                @"age": @25
            }];
            [[person.firstName should] equal:@"Marin"];
            [[person.lastName should] equal:@"Usalj"];
            [[person.age should] equal:theValue(25)];
        });

        it(@"Doesn't create with nulls", ^{
            [[Person create:nil] shouldBeNil];
            [[Person create:(id)[NSNull null]] shouldBeNil];
        });

    });

    context(@"Updating", ^{

        it(@"Can update using dictionary", ^{
            Person *person = [Person create];
            [person update:@{ @"firstName": @"Jonathan", @"age": @50 }];

            [[person.firstName should] equal:@"Jonathan"];
            [[person.age should] equal:@50];
        });

        it(@"sets [NSNull null] properties as nil", ^{
            Person *person = [Person create];
            [person update:@{ @"is_member": @YES }];
            [person update:@{ @"is_member": [NSNull null] }];
            [person.isMember shouldBeNil];
        });

        it(@"stringifies numbers", ^{
            Person *person = [Person create:@{ @"first_name": @123 }];
            [[person.firstName should] equal:@"123"];
        });

        it(@"converts strings to integers", ^{
            Person *person = [Person create:@{ @"age": @"25" }];
            [[person.age should] equal:@25];
        });

        it(@"converts strings to floats", ^{
            Person *person = [Person create:@{ @"savings": @"1500.12" }];
            [[person.savings should] equal:@(1500.12f)];
        });

        it(@"converts strings to dates", ^{
            NSDateFormatter *formatta = [NSDateFormatter new];
            [formatta setDateFormat:@"yyyy-MM-dd HH:mm:ss z"];

            NSDate *date = [NSDate date];
            Person *person = [Person create:@{ @"anniversary": [formatta stringFromDate:date] }];
            [[@([date timeIntervalSinceDate:person.anniversary]) should] beLessThan:@1];
        });

        it(@"doesn't update with nulls", ^{
            Person *person = fetchUniquePerson();
            [person update:nil];
            [person update:(id)[NSNull null]];

            [[person.firstName should] equal:UNIQUE_NAME];
        });

        it(@"doesn't always create new relationship object", ^{
            Car *car = [Car create:@{ @"hp": @150, @"owner": @{ @"firstName": @"asetnset" } }];
            [@3 times:^{
                [car update:@{ @"make": @"Porsche", @"owner": @{ @"firstName": @"asetnset" } }];
            }];
            [[[Person where:@{ @"firstName": @"asetnset" }] should] haveCountOf:1];
        });

        it(@"updates multiple records", ^{
            [Person deleteAll];
            createSomePeople(@[@"Abe", @"Bob", @"Cal", @"Don"],
                             @[@"Zed", @"Mol", @"Gaz", @"Mol"],
                             [NSManagedObjectContext defaultContext]);
            NSDictionary *query = @{ @"lastName" : @"Lee" };
            [Person updateAll:query];
            [[[Person where:query] should] haveCountOf:4];
        });

        it(@"updates multiple records through a query", ^{
            [Person deleteAll];
            createSomePeople(@[@"Abe", @"Bob", @"Cal", @"Don"],
                             @[@"Zed", @"Mol", @"Gaz", @"Mol"],
                             [NSManagedObjectContext defaultContext]);
            NSDictionary *query = @{ @"lastName" : @"Lee" };
            [[Person where:@"lastName = 'Mol'"] updateAll:query];
            [[[Person where:query] should] haveCountOf:2];
        });
    });

    context(@"Saving", ^{

        __block Person *person;

        beforeEach(^{
            person = fetchUniquePerson();
            person.firstName = @"changed attribute for save";
        });

        afterEach(^{
            person.firstName = UNIQUE_NAME;
            [person save];
        });

        it(@"uses the object's context", ^{
            [[person.managedObjectContext should] receive:@selector(save:) andReturn:theValue(YES)];
            [person save];
        });

        it(@"returns YES if save has succeeded", ^{
            [[@([person save]) should] beTrue];
            [[@([person save]) should] beTrue];
        });

        it(@"returns NO if save hasn't succeeded", ^{
            [[person.managedObjectContext should] receive:@selector(save:) andReturn:theValue(NO)];
            [[@([person save]) should] beFalse];
        });

    });


    context(@"Deleting", ^{

        it(@"Deletes the object from database with -delete", ^{
            Person *person = fetchUniquePerson();
            [person shouldNotBeNil];
            [person delete];
            [fetchUniquePerson() shouldBeNil];
        });

        it(@"Deletes everything from database with +deleteAll", ^{
            [Person deleteAll];
            [[[Person all] should] beEmpty];
        });

    });


    context(@"All from above, in a separate context!", ^{

        __block NSManagedObjectContext *newContext;

        beforeEach(^{
            [Person deleteAll];
            [NSManagedObjectContext.defaultContext save:nil];

            newContext = createNewContext();

            [newContext performBlockAndWait:^{
                Person *newPerson = [[Person inContext:newContext] create];
                newPerson.firstName = @"Joshua";
                newPerson.lastName = @"Jobs";
                newPerson.age = [NSNumber numberWithInt:100];
                [newPerson save];
            }];
        });

        it(@"Creates in a separate context", ^{
            [[NSEntityDescription should] receive:@selector(insertNewObjectForEntityForName:inManagedObjectContext:)
                                        andReturn:nil
                                    withArguments:@"Person", newContext];

            [[Person inContext:newContext] create];
        });

        it(@"Creates with dictionary in a separate context", ^{
            [[NSEntityDescription should] receive:@selector(insertNewObjectForEntityForName:inManagedObjectContext:)
                                    withArguments:@"Person", newContext];

            [[Person inContext:newContext] create:[NSDictionary dictionary]];
        });

        it(@"Finds in a separate context", ^{
            [newContext performBlockAndWait:^{
                Person *found = [[[Person where:@{ @"firstName": @"Joshua" }] inContext:newContext] firstObject];
                [[found.lastName should] equal:@"Jobs"];
            }];
        });

        it(@"Finds all in a separate context", ^{
            __block NSManagedObjectContext *anotherContext = createNewContext();
            __block CoreDataRelation *newPeople;

            [anotherContext performBlockAndWait:^{
                [Person deleteAll];
                [NSManagedObjectContext.defaultContext save:nil];

                createSomePeople(names, surnames, anotherContext);
                newPeople = [Person inContext:anotherContext];
            }];

            [[newPeople should] haveCountOf:names.count];
        });

        it(@"Finds the first match in a separate context", ^{
            NSDictionary *attributes = @{ @"firstName": @"Joshua",
                                          @"lastName": @"Jobs" };
            Person *joshua = [[Person inContext:newContext] find:attributes];
            [[joshua.firstName should] equal:@"Joshua"];
        });

        it(@"Finds a limited number of results in a separate context", ^{
            [@4 times:^{
                [newContext performBlockAndWait:^{
                    Person *newPerson = [[Person inContext:newContext] create];
                    newPerson.firstName = @"Joshua";
                    [newPerson save];
                }];
            }];
            CoreDataRelation *people = [[[Person where:@{ @"firstName": @"Joshua"}]
                                             inContext:newContext]
                                                 limit:2];
            [[people should] haveCountOf:2];
        });


        it(@"Find or create in a separate context", ^{
            [newContext performBlockAndWait:^{
                Person *luis = [[Person inContext:newContext] findOrCreate:@{ @"firstName": @"Luis" }];
                [[luis.firstName should] equal:@"Luis"];
            }];
        });

        it(@"Deletes all from context", ^{
            [newContext performBlockAndWait:^{
                [[Person inContext:newContext] deleteAll];
                [[[Person inContext:newContext] should] beEmpty];
            }];
        });

    });


    context(@"With a different class name to the entity name", ^{

        NSManagedObjectContext *newContext = createNewContext();

        it(@"Has the correct entity name", ^{
            [[[OBRPerson entityName] should] equal:@"OtherPerson"];
        });

        it(@"Fetches the correct entity", ^{
            [[NSEntityDescription should] receive:@selector(entityForName:inManagedObjectContext:)
                                        andReturn:[NSEntityDescription entityForName:@"OtherPerson" inManagedObjectContext:newContext]
                                    withArguments:@"OtherPerson", newContext];

            [[OBRPerson inContext:newContext] fetchedObjects];
        });

        it(@"Creates the correct entity", ^{
            [[NSEntityDescription should] receive:@selector(insertNewObjectForEntityForName:inManagedObjectContext:)
                                    withArguments:@"OtherPerson", newContext];

            [[OBRPerson inContext:newContext] create];
        });

    });

    context(@"Relations", ^{

        __block Person *subordinate;
        __block Person *manager;

        beforeEach(^{
            subordinate = [Person create:@{@"firstName": @"Stanley"}];
            manager = [Person create:@{@"firstName": @"Narrator",
                                       @"employees": @[subordinate]}];
        });

        it(@"Returns existent relationships", ^{
            CoreDataRelation *employees = [manager relationWithName:@"employees"];
            [[[employees firstObject] should] equal:subordinate];
            [[employees find:@"firstName = %@", @"Stephen"] shouldBeNil];
        });

        it(@"Doesn't return non-existent relationships", ^{
            [[manager relationWithName:@"trucks"] shouldBeNil];
        });

        it(@"Builds relations from CoreDataRelation properties", ^{
            [[manager.employees should] beKindOfClass:[CoreDataRelation class]];
        });

        it(@"Doesn't build relations from NSSet properties", ^{
            [[manager.cars should] beKindOfClass:[NSSet class]];
        });

        it(@"Creates through relationships", ^{
            [manager.employees create:@{@"firstName": @"Stephen"}];
            [[manager.employees find:@"firstName = %@", @"Stephen"] shouldNotBeNil];
        });

    });

    context(@"Fetch requests / fetched results controllers", ^{

        it(@"Sets batch size", ^{
            NSUInteger batchSize = 100;
            CoreDataRelation *people = [Person inBatchesOf:batchSize];

            [[@([[people fetchRequest] fetchBatchSize]) should] equal:@(batchSize)];
        });

        it(@"Returns a fetched results controller with the proper fetch request", ^{
            NSUInteger batchSize = 100;
            CoreDataRelation *people = [Person inBatchesOf:batchSize];
            NSFetchedResultsController *fetchedResultsController = [people fetchedResultsController];

            [[fetchedResultsController should] beKindOfClass:[NSFetchedResultsController class]];
            [[@([fetchedResultsController.fetchRequest fetchBatchSize]) should] equal:@(batchSize)];
        });

        it(@"Sets section name and cache name", ^{
            NSString *attribute = NSStringFromSelector(@selector(lastName));

            NSFetchedResultsController *fetchedResultsController = [[Person order:attribute] fetchedResultsControllerWithSectionNameKeyPath:attribute cacheName:attribute];

            [[fetchedResultsController.sectionNameKeyPath should] equal:attribute];
            [[fetchedResultsController.cacheName should] equal:attribute];
        });

    });

});

SPEC_END

